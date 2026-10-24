"""Admin CRUD for plain tables, described once and published to the console.

`resource(...)` registers four routes under /api/v1/admin/<name>:

    GET    /admin/<name>?q=&<filter>=   list (search + equality filters)
    POST   /admin/<name>                create
    PATCH  /admin/<name>/<id>           partial update
    DELETE /admin/<name>/<id>           delete (or deactivate when soft)

and records the field list in RESOURCES, which `/admin/meta` serves so the
web console can render the table and form without hard-coding them.
"""
import json
import re
import sqlite3
from datetime import date, datetime

from flask import jsonify, request

from .common import ApiError, audit, bp, connect, json_body, require_staff

RESOURCES = {}


class Field:
    """One editable column.

    kind: text | int | float | bool | date | datetime | time | choice | list | ref
    ref:  for kind=ref, the resource name whose ids are valid (rendered as a picker)
    """

    def __init__(self, name, kind="text", *, label=None, required=False, max_len=200, choices=None,
                 ref=None, default=None, min=None, max=None, help=None, list_column=True):
        self.name, self.kind, self.required = name, kind, required
        self.label = label or name.replace("_", " ").capitalize()
        self.max_len, self.choices, self.ref, self.default = max_len, choices, ref, default
        self.min, self.max, self.help, self.list_column = min, max, help, list_column

    def meta(self):
        return {k: v for k, v in {
            "name": self.name, "kind": self.kind, "label": self.label, "required": self.required,
            "choices": self.choices, "ref": self.ref, "default": self.default, "min": self.min, "max": self.max,
            "help": self.help, "list_column": self.list_column,
            "max_len": self.max_len if self.kind == "text" else None}.items() if v is not None}

    def clean(self, value):
        """Validates and converts one incoming value for the database."""
        name = self.name
        if value is None or (isinstance(value, str) and value.strip() == "" and self.kind != "text"):
            if self.required:
                raise ApiError(400, "invalid_field", f"'{name}' is required.")
            return None
        k = self.kind
        if k == "text":
            if not isinstance(value, str):
                raise ApiError(400, "invalid_field", f"'{name}' must be text.")
            value = value.strip()
            if self.required and not value:
                raise ApiError(400, "invalid_field", f"'{name}' is required.")
            if len(value) > self.max_len:
                raise ApiError(400, "invalid_field", f"'{name}' is longer than {self.max_len} characters.")
            return value or None
        if k in ("int", "ref"):
            try:
                v = int(value)
            except (TypeError, ValueError):
                raise ApiError(400, "invalid_field", f"'{name}' must be a whole number.")
            self._range(v)
            return v
        if k == "float":
            try:
                v = float(value)
            except (TypeError, ValueError):
                raise ApiError(400, "invalid_field", f"'{name}' must be a number.")
            self._range(v)
            return v
        if k == "bool":
            if isinstance(value, bool):
                return int(value)
            if value in (0, 1, "0", "1", "true", "false"):
                return int(value in (1, "1", "true"))
            raise ApiError(400, "invalid_field", f"'{name}' must be true or false.")
        if k == "date":
            try:
                return date.fromisoformat(str(value)).isoformat()
            except ValueError:
                raise ApiError(400, "invalid_field", f"'{name}' must be YYYY-MM-DD.")
        if k == "datetime":
            text = str(value).strip().replace("T", " ")
            for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
                try:
                    return datetime.strptime(text, fmt).strftime("%Y-%m-%d %H:%M:%S")
                except ValueError:
                    pass
            raise ApiError(400, "invalid_field", f"'{name}' must be YYYY-MM-DD HH:MM.")
        if k == "time":
            if not re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", str(value)):
                raise ApiError(400, "invalid_field", f"'{name}' must be HH:MM (24-hour).")
            return str(value)
        if k == "choice":
            if value not in self.choices:
                raise ApiError(400, "invalid_field", f"'{name}' must be one of {', '.join(map(str, self.choices))}.")
            return value
        if k == "list":
            if isinstance(value, str):
                value = [v.strip() for v in value.split(",") if v.strip()]
            if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
                raise ApiError(400, "invalid_field", f"'{name}' must be a list of text.")
            return json.dumps(value[:30])
        raise ApiError(500, "bad_field", name)

    def _range(self, v):
        if (self.min is not None and v < self.min) or (self.max is not None and v > self.max):
            raise ApiError(400, "invalid_field", f"'{self.name}' must be between {self.min} and {self.max}.")

    def out(self, value):
        if self.kind == "bool" and value is not None:
            return bool(value)
        if self.kind == "list":
            try:
                return json.loads(value) if value else []
            except ValueError:
                return []
        return value


def resource(name, table, fields, *, label, read_roles=("registrar",), write_roles=("registrar",),
             order_by="id DESC", search=(), filters=(), soft_delete=False, pk="id", defaults=None,
             before_save=None, after_change=None, group="School", where=None):
    """Registers the CRUD routes for [table]. See the module docstring."""
    by_name = {f.name: f for f in fields}
    defaults = defaults or {}
    pk_sql = "rowid" if pk == "rowid" else pk
    RESOURCES[name] = {"name": name, "label": label, "group": group, "fields": [f.meta() for f in fields],
                       "filters": list(filters), "search": bool(search), "soft_delete": soft_delete,
                       "write_roles": sorted(set(write_roles) | {"admin"}),
                       "read_roles": sorted(set(read_roles) | set(write_roles) | {"admin"})}

    def row_out(r):
        out = {"id": r["_id"]}
        for f in fields:
            out[f.name] = f.out(r[f.name])
        return out

    def list_items():
        sql = f"SELECT {pk_sql} AS _id, * FROM {table} WHERE {where or '1=1'}"
        args = []
        q = (request.args.get("q") or "").strip()[:60]
        if q and search:
            sql += " AND (" + " OR ".join(f"{col} LIKE ?" for col in search) + ")"
            args += [f"%{q}%"] * len(search)
        for col in filters:
            v = request.args.get(col)
            if v not in (None, ""):
                sql += f" AND {col} = ?"
                args.append(v)
        with connect() as c:
            rows = c.execute(f"{sql} ORDER BY {order_by} LIMIT 1000", args).fetchall()
        return jsonify(items=[row_out(r) for r in rows])

    def create_item():
        d = json_body()
        values = {}
        for f in fields:
            raw = d.get(f.name, f.default)
            values[f.name] = f.clean(raw)
        values.update({k: (v() if callable(v) else v) for k, v in defaults.items() if k not in values})
        if before_save:
            before_save(values, None)
        cols = ", ".join(values)
        try:
            with connect(write=True) as c:
                cur = c.execute(f"INSERT INTO {table} ({cols}) VALUES ({', '.join('?' * len(values))})",
                                list(values.values()))
                new_id = cur.lastrowid
                audit(c, f"{name}.create", f"#{new_id}")
                if after_change:
                    after_change(c, "create", new_id, values)
                row = c.execute(f"SELECT {pk_sql} AS _id, * FROM {table} WHERE {pk_sql} = ?", (new_id,)).fetchone()
        except sqlite3.IntegrityError as e:
            raise ApiError(409, "conflict", f"That {label.lower().rstrip('s')} already exists ({e}).")
        return jsonify(id=new_id, item=row_out(row)), 201

    def update_item(item_id):
        d = json_body()
        unknown = set(d) - set(by_name)
        if unknown:
            raise ApiError(400, "invalid_field", f"Unknown field(s): {', '.join(sorted(unknown))}.")
        values = {k: by_name[k].clean(v) for k, v in d.items()}
        if not values:
            raise ApiError(400, "invalid_body", "Nothing to update.")
        if before_save:
            before_save(values, item_id)
        sets = ", ".join(f"{k} = ?" for k in values)
        try:
            with connect(write=True) as c:
                n = c.execute(f"UPDATE {table} SET {sets} WHERE {pk_sql} = ? AND {where or '1=1'}",
                              [*values.values(), item_id]).rowcount
                if n == 0:
                    raise ApiError(404, "not_found", "Not found.")
                audit(c, f"{name}.update", f"#{item_id} {sorted(values)}")
                if after_change:
                    after_change(c, "update", item_id, values)
                row = c.execute(f"SELECT {pk_sql} AS _id, * FROM {table} WHERE {pk_sql} = ?", (item_id,)).fetchone()
        except sqlite3.IntegrityError as e:
            raise ApiError(409, "conflict", f"That conflicts with an existing record ({e}).")
        return jsonify(item=row_out(row))

    def delete_item(item_id):
        with connect(write=True) as c:
            if soft_delete:
                n = c.execute(f"UPDATE {table} SET active = 0 WHERE {pk_sql} = ? AND {where or '1=1'}",
                              (item_id,)).rowcount
            else:
                n = c.execute(f"DELETE FROM {table} WHERE {pk_sql} = ? AND {where or '1=1'}", (item_id,)).rowcount
            if n == 0:
                raise ApiError(404, "not_found", "Not found.")
            audit(c, f"{name}.delete", f"#{item_id}")
            if after_change:
                after_change(c, "delete", item_id, {})
        return jsonify(success=True)

    reader = require_staff(*read_roles, *write_roles)
    writer = require_staff(*write_roles)
    bp.add_url_rule(f"/admin/{name}", f"crud_{name}_list", reader(list_items), methods=["GET"])
    bp.add_url_rule(f"/admin/{name}", f"crud_{name}_create", writer(create_item), methods=["POST"])
    bp.add_url_rule(f"/admin/{name}/<int:item_id>", f"crud_{name}_update", writer(update_item), methods=["PATCH"])
    bp.add_url_rule(f"/admin/{name}/<int:item_id>", f"crud_{name}_delete", writer(delete_item), methods=["DELETE"])


def now_stamp():
    from .common import now_text
    return now_text()


def today_iso():
    from .common import now_dt
    return now_dt().date().isoformat()


__all__ = ["Field", "RESOURCES", "resource", "now_stamp", "today_iso"]
