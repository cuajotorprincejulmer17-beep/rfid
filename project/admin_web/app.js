/* PULSE admin console. Plain JS, no build step, no network beyond this server. */
"use strict";

const API = "/api/v1";
const TOKEN_KEY = "pulse_admin_token";
const S = { token: null, staff: null, meta: null, refs: {}, timers: [] };

// ------------------------------------------------------------------ tiny DOM helpers
const $ = (sel, root = document) => root.querySelector(sel);

function h(tag, attrs, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") el.className = v;
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v);
    else if (k === "value") el.value = v;
    else if (v === true) el.setAttribute(k, "");
    else el.setAttribute(k, v);
  }
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

function toast(msg, bad = false) {
  const t = $("#toast");
  t.textContent = msg;
  t.className = "toast" + (bad ? " bad" : "");
  t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.hidden = true), bad ? 6000 : 3000);
}

function storeGet(k) { try { return sessionStorage.getItem(k); } catch { return null; } }
function storeSet(k, v) { try { v === null ? sessionStorage.removeItem(k) : sessionStorage.setItem(k, v); } catch { /* private mode */ } }

// ------------------------------------------------------------------ API
class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

async function api(method, path, body, { raw = null, contentType = "application/json", blob = false } = {}) {
  const headers = { Accept: "application/json" };
  if (S.token) headers.Authorization = "Bearer " + S.token;
  let payload;
  if (raw !== null) { payload = raw; headers["Content-Type"] = contentType; }
  else if (body !== undefined) { payload = JSON.stringify(body); headers["Content-Type"] = "application/json"; }
  const res = await fetch(API + path, { method, headers, body: payload });
  if (res.status === 401 && path !== "/admin/auth/login") { signOut(true); throw new ApiError(401, "unauthorized", "Please sign in again."); }
  if (blob && res.ok) return res.blob();
  let data = null;
  try { data = await res.json(); } catch { /* empty body */ }
  if (!res.ok) {
    const err = (data && data.error) || {};
    throw new ApiError(res.status, err.code || "http_" + res.status, err.message || "Request failed (" + res.status + ").");
  }
  return data;
}

// True when [data] is the same as the last value seen under [key]: live views
// then skip re-rendering, so buttons stay put under the user's pointer.
const lastSeen = {};
function unchanged(key, data) {
  const text = JSON.stringify(data);
  if (lastSeen[key] === text) return true;
  lastSeen[key] = text;
  return false;
}

async function guard(fn) {
  try { return await fn(); }
  catch (e) { if (e.status !== 401) toast(e.message || String(e), true); return null; }
}

async function download(path, filename) {
  const blob = await guard(() => api("GET", path, undefined, { blob: true }));
  if (!blob) return;
  const url = URL.createObjectURL(blob);
  const a = h("a", { href: url, download: filename });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// ------------------------------------------------------------------ formatting
const today = () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);
const thisMonth = () => today().slice(0, 7);
const hhmm = (t) => (t ? t.slice(11, 16) : "—");
const dash = (v) => (v === null || v === undefined || v === "" ? "—" : v);

const STATUS_TONE = {
  present: "ok", late: "warn", absent: "bad", excused: "info", not_yet: "", upcoming: "", holiday: "", no_class: "",
  no_school: "", granted: "ok", warning: "warn", denied: "bad", pending: "warn", approved: "ok", rejected: "bad",
  open: "warn", answered: "ok", closed: "", claim_requested: "warn", claimed: "ok", reserved: "warn", borrowed: "info",
  returned: "ok", cancelled: "", sent: "ok", failed: "bad", skipped: "",
};
const LABEL = { not_yet: "not yet", no_class: "no class", no_school: "no school", claim_requested: "claim requested" };
const pill = (s) => h("span", { class: "pill " + (STATUS_TONE[s] ?? "") }, LABEL[s] || s || "—");

function can(...roles) { return S.staff && (S.staff.role === "admin" || roles.includes(S.staff.role)); }

// ------------------------------------------------------------------ modal + forms
function openModal(title, content) {
  $("#modalTitle").textContent = title;
  const body = $("#modalBody");
  body.replaceChildren(content);
  $("#modal").hidden = false;
  const first = body.querySelector("input, select, textarea");
  if (first) first.focus();
}
function closeModal() { $("#modal").hidden = true; $("#modalBody").replaceChildren(); }

function refLabel(x) {
  if (x.student_number !== undefined && x.name) return x.student_number ? `${x.name} (${x.student_number})` : x.name;
  if (x.code && x.title) return `${x.code} – ${x.title}`;
  if (x.code && x.name) return `${x.code} – ${x.name}`;
  return x.full_name || x.name || x.title || x.code || x.username || "#" + x.id;
}

async function refOptions(ref) {
  if (!S.refs[ref]) {
    const data = await api("GET", "/admin/" + ref);
    S.refs[ref] = data.items.map((x) => ({ value: x.id, label: refLabel(x) }));
  }
  return S.refs[ref];
}
function dropRefs() { S.refs = {}; }

async function inputFor(f, value) {
  const name = f.name;
  const v = value === undefined || value === null ? (f.default ?? "") : value;
  switch (f.kind) {
    case "bool":
      return h("input", { type: "checkbox", name, checked: v === true || v === 1 });
    case "int": case "float":
      return h("input", { type: "number", name, step: f.kind === "float" ? "any" : "1", min: f.min, max: f.max, value: v, required: f.required });
    case "date": return h("input", { type: "date", name, value: v, required: f.required });
    case "time": return h("input", { type: "time", name, value: v, required: f.required });
    case "datetime": return h("input", { type: "datetime-local", name, value: v ? String(v).slice(0, 16).replace(" ", "T") : "", required: f.required });
    case "choice":
      return h("select", { name, required: f.required },
        f.required ? null : h("option", { value: "" }, "—"),
        f.choices.map((c) => h("option", { value: c, selected: String(c) === String(v) },
          f.name === "weekday" && S.meta ? S.meta.weekdays[c] : String(c))));
    case "list":
      return h("input", { name, value: Array.isArray(v) ? v.join(", ") : v, placeholder: "comma, separated" });
    case "ref": {
      const opts = await refOptions(f.ref);
      return h("select", { name, required: f.required },
        h("option", { value: "" }, f.required ? "Choose…" : "—"),
        opts.map((o) => h("option", { value: o.value, selected: String(o.value) === String(v) }, o.label)));
    }
    default:
      if ((f.max_len || 0) > 200) return h("textarea", { name, required: f.required }, v);
      return h("input", { name, value: v, maxlength: f.max_len, required: f.required });
  }
}

function readField(form, f) {
  const el = form.elements[f.name];
  if (!el) return undefined;
  if (f.kind === "bool") return el.checked;
  const raw = el.value.trim();
  if (raw === "") return null;
  if (f.kind === "int" || f.kind === "ref") return parseInt(raw, 10);
  if (f.kind === "float") return parseFloat(raw);
  if (f.kind === "choice") return f.choices.find((c) => String(c) === raw) ?? raw;
  if (f.kind === "datetime") return raw.replace("T", " ");
  return raw;
}

async function formFor(fields, values, submitLabel, onSubmit) {
  const form = h("form", { class: "form" });
  for (const f of fields) {
    const input = await inputFor(f, values ? values[f.name] : undefined);
    form.append(h("label", {}, f.label + (f.required ? " *" : ""), input, f.help ? h("span", { class: "help muted" }, f.help) : null));
  }
  const err = h("p", { class: "error", hidden: true });
  const btn = h("button", { class: "btn primary", type: "submit" }, submitLabel);
  form.append(err, h("div", { class: "actions" }, h("button", { class: "btn", type: "button", onclick: closeModal }, "Cancel"), btn));
  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const data = {};
    for (const f of fields) data[f.name] = readField(form, f);
    btn.disabled = true; err.hidden = true;
    try { await onSubmit(data); }
    catch (e) { err.textContent = e.message; err.hidden = false; }
    finally { btn.disabled = false; }
  });
  return form;
}

function simpleForm(fields, submitLabel, onSubmit) { return formFor(fields, null, submitLabel, onSubmit); }

function table(columns, rows, emptyText = "Nothing here yet.") {
  if (!rows.length) return h("div", { class: "table-wrap" }, h("div", { class: "empty" }, emptyText));
  return h("div", { class: "table-wrap" }, h("table", {},
    h("thead", {}, h("tr", {}, columns.map((c) => h("th", {}, c.label)))),
    h("tbody", {}, rows.map((r) => h("tr", {}, columns.map((c) => {
      const v = c.render ? c.render(r) : dash(r[c.key]);
      return h("td", { class: c.wrap ? "wrap" : null }, v);
    }))))));
}

function kpis(items) {
  return h("div", { class: "cards" }, items.map(([label, value]) =>
    h("div", { class: "kpi" }, h("div", { class: "label" }, label), h("div", { class: "value" }, dash(value)))));
}

function showSecret(title, lines, secret, note) {
  openModal(title, h("div", { class: "form" },
    lines.map((l) => h("p", {}, l)),
    h("div", { class: "secret" }, secret),
    h("p", { class: "muted small" }, note || "Copy it now: it is shown only once."),
    h("div", { class: "actions" }, h("button", { class: "btn primary", onclick: closeModal }, "Done"))));
}

async function sectionSelect(value, { all = true, name = "section_id" } = {}) {
  const opts = await guard(() => refOptions("sections")) || [];
  return h("select", { name }, all ? h("option", { value: "" }, "All sections") : h("option", { value: "" }, "—"),
    opts.map((o) => h("option", { value: o.value, selected: String(o.value) === String(value ?? "") }, o.label)));
}

// ------------------------------------------------------------------ pages
const PAGES = [];
function page(id, title, group, roles, render) { PAGES.push({ id, title, group, roles, render }); }

page("dashboard", "Dashboard", "Overview", null, async (view) => {
  const load = async () => {
    const d = await guard(() => api("GET", "/admin/dashboard"));
    if (!d || unchanged("dashboard", d)) return;
    const t = d.totals;
    view.replaceChildren(
      kpis([["Students", t.students], ["Present", t.present], ["Late", t.late],
        ["Absent", t.absent], ["Not yet in", t.not_yet], ["Inside now", d.inside_now], ["Visitors today", d.visitors_today]]),
      h("div", { class: "grid2" },
        h("div", { class: "panel" }, h("h3", {}, "Readers"),
          table([{ label: "Reader", render: (x) => h("span", {}, h("span", { class: "dot " + (x.online ? "ok" : "bad") }), x.code) },
            { label: "Name", key: "name" }, { label: "Mode", key: "mode" }, { label: "Last seen", key: "last_seen" }],
          d.devices, "No readers yet.")),
        h("div", { class: "panel" }, h("h3", {}, "Waiting for staff"),
          table([{ label: "Item", key: "k" }, { label: "Count", key: "v" }],
            [["Excuse letters", d.pending.excuses], ["Support tickets", d.pending.tickets],
              ["Lost-item claims", d.pending.claims], ["Library reservations", d.pending.reservations],
              ["Flagged records (7 days)", d.flags_last_7_days]].map(([k, v]) => ({ k, v }))))),
      h("div", { class: "panel" }, h("h3", {}, "Latest taps"),
        table([{ label: "Time", render: (x) => hhmm(x.received_at) }, { label: "Reader", key: "device" },
          { label: "Card", key: "uid" }, { label: "Name", key: "name" }, { label: "Role", key: "role" },
          { label: "Result", render: (x) => pill(x.status) }, { label: "Code", key: "result_code" }],
        d.recent_taps, "No taps yet today.")));
  };
  await load();
  S.timers.push(setInterval(load, 5000));
});

page("attendance", "Daily attendance", "Attendance", null, async (view) => {
  const date = h("input", { type: "date", value: today() });
  const section = await sectionSelect("");
  const out = h("div");
  const q = () => `?date=${date.value}` + (section.value ? `&section_id=${section.value}` : "");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/reports/daily" + q()));
    if (!r) return;
    const t = r.totals;
    out.replaceChildren(
      kpis([["Students", t.students], ["Present", t.present], ["Late", t.late], ["Absent", t.absent],
        ["Excused", t.excused], ["Not yet", t.not_yet]]),
      table([{ label: "Student no.", key: "student_number" }, { label: "Name", key: "name" }, { label: "Section", key: "section" },
        { label: "Status", render: (x) => pill(x.day_status) }, { label: "Late", render: (x) => (x.late_minutes ? x.late_minutes + " min" : "—") },
        { label: "In", render: (x) => hhmm(x.time_in) }, { label: "Out", render: (x) => hhmm(x.time_out) },
        { label: "", render: (x) => (x.missing_time_out ? pill("missing time out") : "") }], r.rows, "No students in this view."));
  };
  date.onchange = load; section.onchange = load;
  view.replaceChildren(h("div", { class: "toolbar" }, date, section, h("span", { class: "spacer" }),
    h("button", { class: "btn", onclick: () => download("/admin/reports/daily.csv" + q(), `attendance-${date.value}.csv`) }, "Download CSV")), out);
  await load();
});

page("monthly", "Monthly summary", "Attendance", null, async (view) => {
  const month = h("input", { type: "month", value: thisMonth() });
  const section = await sectionSelect("");
  const out = h("div");
  const q = () => `?month=${month.value}` + (section.value ? `&section_id=${section.value}` : "");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/reports/monthly" + q()));
    if (!r) return;
    out.replaceChildren(table([{ label: "Student no.", key: "student_number" }, { label: "Name", key: "name" },
      { label: "Section", key: "section" }, { label: "School days", key: "school_days" }, { label: "Present", key: "present" },
      { label: "Late", key: "late" }, { label: "Absent", key: "absent" }, { label: "Excused", key: "excused" },
      { label: "Rate", render: (x) => (x.rate === null ? "—" : x.rate + "%") }, { label: "Late min", key: "late_minutes_total" },
      { label: "", render: (x) => h("button", { class: "btn small", onclick: () => studentMonth(x.user_id, month.value) }, "Days") }],
    r.rows, "No students in this view."));
  };
  month.onchange = load; section.onchange = load;
  view.replaceChildren(h("div", { class: "toolbar" }, month, section, h("span", { class: "spacer" }),
    h("button", { class: "btn", onclick: () => download("/admin/reports/monthly.csv" + q(), `attendance-${month.value}.csv`) }, "Download CSV")), out);
  await load();
});

async function studentMonth(userId, month) {
  const r = await guard(() => api("GET", `/admin/reports/student/${userId}?month=${month}`));
  if (!r) return;
  const s = r.summary;
  openModal(`${r.name} — ${r.month}`, h("div", {},
    h("p", { class: "muted" }, `Present ${s.present} · Late ${s.late} · Absent ${s.absent} · Excused ${s.excused} · Rate ${s.rate ?? "—"}%`),
    table([{ label: "Date", key: "date" }, { label: "Status", render: (x) => pill(x.day_status) },
      { label: "In", render: (x) => hhmm(x.time_in) }, { label: "Out", render: (x) => hhmm(x.time_out) },
      { label: "Late", render: (x) => (x.late_minutes ? x.late_minutes + " min" : "") }], r.days)));
}

page("logs", "Tap records", "Attendance", null, async (view) => {
  const date = h("input", { type: "date", value: today() });
  const search = h("input", { placeholder: "Name or student no." });
  const flag = h("select", {}, h("option", { value: "" }, "All records"),
    ["MISSING_TIME_OUT", "OVERSTAY"].map((f) => h("option", { value: f }, f)));
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", `/admin/logs?date=${date.value}&q=${encodeURIComponent(search.value)}&flag=${flag.value}`));
    if (!r) return;
    out.replaceChildren(table([{ label: "In", render: (x) => hhmm(x.time_in) }, { label: "Out", render: (x) => hhmm(x.time_out) },
      { label: "Name", key: "name" }, { label: "Role", key: "role" }, { label: "Student no.", key: "student_number" },
      { label: "Section", key: "section" }, { label: "Reader", key: "device" }, { label: "Flag", render: (x) => (x.flag ? pill(x.flag) : "") },
      { label: "", render: (x) => (can("registrar") ? h("button", { class: "btn small", onclick: () => fixLog(x, load) }, "Correct") : "") }],
    r.items, "No tap records for this day."));
  };
  date.onchange = load; flag.onchange = load; search.oninput = () => { clearTimeout(search._t); search._t = setTimeout(load, 300); };
  view.replaceChildren(h("div", { class: "toolbar" }, date, search, flag), out);
  await load();
});

async function fixLog(row, reload) {
  const form = await simpleForm([
    { name: "time_out", kind: "time", label: "Time out (HH:MM)", help: `Time in was ${hhmm(row.time_in)}. Leave blank to keep.` },
    { name: "clear_flag", kind: "bool", label: "Clear the flag" }], "Save correction", async (d) => {
    const body = {};
    if (d.time_out) body.time_out = d.time_out;
    if (d.clear_flag) body.clear_flag = true;
    await api("PATCH", `/admin/logs/${row.id}`, body);
    closeModal(); toast("Record corrected."); reload();
  });
  openModal(`Correct: ${row.name}`, form);
}

page("students", "Students", "People", ["registrar", "teacher", "guard"], async (view) => {
  const search = h("input", { placeholder: "Search name or number" });
  const section = await sectionSelect("");
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", `/admin/students?q=${encodeURIComponent(search.value)}` + (section.value ? `&section_id=${section.value}` : "")));
    if (!r) return;
    out.replaceChildren(table([
      { label: "Name", key: "name" }, { label: "Student no.", key: "student_number" }, { label: "Section", render: (x) => dash(x.section_name || x.course_section) },
      { label: "Card UID", key: "rfid_uid" }, { label: "App", render: (x) => (x.claimed ? pill("active") : x.has_profile ? pill("not claimed") : pill("no profile")) },
      { label: "Guardians", key: "guardians" },
      { label: "", render: (x) => h("span", {},
        h("button", { class: "btn small", onclick: () => studentMonth(x.id, thisMonth()) }, "Attendance"),
        can("registrar") ? [
          h("button", { class: "btn small", onclick: () => editStudent(x, load) }, "Edit"),
          x.has_profile && !x.claimed ? h("button", { class: "btn small", onclick: () => claimCode(x) }, "App code") : null,
          x.claimed ? h("button", { class: "btn small", onclick: () => resetAccount(x, load) }, "Reset app") : null,
          h("button", { class: "btn small", onclick: () => go("guardians", { user_id: x.id }) }, "Guardians"),
          h("button", { class: "btn small danger", onclick: () => deleteCard(x, load) }, "Delete")] : null) }],
    r.items, "No students found."));
  };
  search.oninput = () => { clearTimeout(search._t); search._t = setTimeout(load, 300); };
  section.onchange = load;
  view.replaceChildren(h("div", { class: "toolbar" }, search, section, h("span", { class: "spacer" }),
    can("registrar") ? [h("button", { class: "btn", onclick: () => importStudents(load) }, "Import CSV"),
      h("button", { class: "btn primary", onclick: () => addStudent(load) }, "Add student")] : null), out);
  await load();
});

async function lastUnknownUid() {
  const r = await api("GET", "/admin/taps?unknown=1&limit=1");
  return r.items.length ? r.items[0] : null;
}

async function addStudent(reload, uid = "") {
  const sections = await guard(() => refOptions("sections")) || [];
  const form = await simpleForm([
    { name: "uid", label: "Card UID", required: true, help: "Tap the new card on any reader, then press “Use last tapped card”." },
    { name: "name", label: "Full name", required: true },
    { name: "student_number", label: "Student number", required: true },
    { name: "section_id", kind: "choice", label: "Section", choices: sections.map((s) => s.value) },
    { name: "phone", label: "Phone" }], "Register student", async (d) => {
    const body = { uid: d.uid, name: d.name, student_number: d.student_number, phone: d.phone || null };
    if (d.section_id) body.section_id = Number(d.section_id);
    await api("POST", "/admin/students", body);
    closeModal(); toast("Student registered."); reload();
  });
  // Show section names instead of ids, and add the "last tap" helper.
  const sel = form.elements.section_id;
  [...sel.options].forEach((o) => { const s = sections.find((x) => String(x.value) === o.value); if (s) o.textContent = s.label; });
  form.elements.uid.value = uid;
  form.elements.uid.after(h("button", { class: "btn small", type: "button", onclick: async () => {
    const t = await guard(lastUnknownUid);
    if (t) { form.elements.uid.value = t.uid; toast(`Card ${t.uid} from ${t.device} at ${hhmm(t.received_at)}`); }
    else toast("No unregistered card has been tapped yet.", true);
  } }, "Use last tapped card"));
  openModal("Add student", form);
}

async function editStudent(x, reload) {
  const form = await simpleForm([
    { name: "student_number", label: "Student number", required: true },
    { name: "section_id", kind: "ref", ref: "sections", label: "Section" },
    { name: "course_section", label: "Course / section text", help: "Filled from the section when left blank." },
    { name: "phone", label: "Phone" }], "Save", async (d) => {
    await api("PUT", `/admin/students/${x.id}/profile`, { student_number: d.student_number, section_id: d.section_id,
      course_section: d.course_section, phone: d.phone });
    closeModal(); toast("Profile saved."); reload();
  });
  form.elements.student_number.value = x.student_number || "";
  form.elements.section_id.value = x.section_id || "";
  form.elements.course_section.value = x.section_id ? "" : (x.course_section || "");
  form.elements.phone.value = x.phone || "";
  openModal(`Edit ${x.name}`, form);
}

async function claimCode(x) {
  const r = await guard(() => api("POST", `/admin/students/${x.id}/claim-code`, { expires_hours: 72 }));
  if (r) showSecret("App activation code", [`Give this to ${x.name} (${r.student_number}) in person.`,
    `It works once and expires ${new Date(r.expires_at).toLocaleString()}.`], r.claim_code,
  "The student opens the app → “First time? Activate your account”. The code is shown only once.");
}

async function resetAccount(x, reload) {
  if (!confirm(`Reset ${x.name}'s app account? They will need a new activation code.`)) return;
  if (await guard(() => api("POST", `/admin/students/${x.id}/reset-account`))) { toast("App account reset."); reload(); }
}

async function deleteCard(x, reload) {
  if (!confirm(`Delete ${x.name} and ALL their attendance history? This cannot be undone.`)) return;
  if (await guard(() => api("DELETE", `/admin/cards/${x.id}`))) { toast("Deleted."); dropRefs(); reload(); }
}

async function importStudents(reload) {
  const file = h("input", { type: "file", accept: ".csv,text/csv" });
  const text = h("textarea", { placeholder: "uid,name,student_number,section,phone\n04A1B2C3,Juan Dela Cruz,2026-0001,BSIT - 2A,09171234567" });
  file.onchange = async () => { if (file.files[0]) text.value = await file.files[0].text(); };
  const result = h("div");
  openModal("Import students (CSV)", h("div", { class: "form" },
    h("p", { class: "muted" }, "Header row: uid,name,student_number,section,phone. Section must match an existing section name."),
    file, text, result,
    h("div", { class: "actions" }, h("button", { class: "btn", onclick: closeModal }, "Close"),
      h("button", { class: "btn primary", onclick: async () => {
        const r = await guard(() => api("POST", "/admin/students/import", undefined, { raw: text.value, contentType: "text/csv" }));
        if (!r) return;
        result.replaceChildren(h("p", {}, `${r.created.length} created, ${r.skipped.length} skipped.`),
          r.skipped.length ? table([{ label: "Line", key: "line" }, { label: "Reason", key: "reason", wrap: true }], r.skipped) : "");
        reload();
      } }, "Import"))));
}

page("cards", "Cards & visitors", "People", ["registrar", "guard"], async (view) => {
  const role = h("select", {}, h("option", { value: "" }, "All cards"), h("option", { value: "visitor" }, "Visitors"), h("option", { value: "student" }, "Students"));
  const search = h("input", { placeholder: "Name, number or UID" });
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", `/admin/cards?role=${role.value}&q=${encodeURIComponent(search.value)}`));
    if (!r) return;
    out.replaceChildren(table([{ label: "Card UID", key: "rfid_uid" }, { label: "Name", key: "name" }, { label: "Role", key: "role" },
      { label: "Student no.", key: "student_number" }, { label: "Visit limit", render: (x) => (x.time_limit_minutes ? x.time_limit_minutes + " min" : "—") },
      { label: "Status", render: (x) => (x.is_expired ? pill("expired") : pill("active")) }, { label: "Registered", key: "registered_at" },
      { label: "", render: (x) => (can("registrar") ? h("button", { class: "btn small danger", onclick: () => deleteCard(x, load) }, "Delete") : "") }], r.items));
  };
  role.onchange = load; search.oninput = () => { clearTimeout(search._t); search._t = setTimeout(load, 300); };
  view.replaceChildren(h("div", { class: "toolbar" }, role, search, h("span", { class: "spacer" }),
    h("button", { class: "btn primary", onclick: () => registerVisitor(load) }, "Register visitor card")), out);
  await load();
});

async function registerVisitor(reload, uid = "") {
  const form = await simpleForm([
    { name: "uid", label: "Card UID", required: true },
    { name: "name", label: "Visitor name", required: true },
    { name: "time_limit_minutes", kind: "int", label: "Visit limit (minutes)", min: 1, max: 1440, help: "Blank = the school default." }],
  "Register", async (d) => {
    const r = await api("POST", "/admin/cards", { uid: d.uid, name: d.name, role: "visitor", time_limit_minutes: d.time_limit_minutes });
    closeModal(); toast(r.message); reload && reload();
  });
  form.elements.uid.value = uid;
  form.elements.uid.after(h("button", { class: "btn small", type: "button", onclick: async () => {
    const t = await guard(lastUnknownUid);
    if (t) form.elements.uid.value = t.uid; else toast("No unregistered card has been tapped yet.", true);
  } }, "Use last tapped card"));
  openModal("Register visitor card", form);
}

page("readers", "RFID readers", "People", ["registrar", "guard"], async (view) => {
  const devs = h("div"), taps = h("div");
  const unknownOnly = h("input", { type: "checkbox" });
  const loadDevices = async () => {
    const r = await guard(() => api("GET", "/admin/devices"));
    if (!r || unchanged("devices", r)) return;
    devs.replaceChildren(table([
      { label: "Reader", render: (x) => h("span", {}, h("span", { class: "dot " + (x.online ? "ok" : "bad") }), x.code) },
      { label: "Name", key: "name" }, { label: "Location", key: "location" }, { label: "Mode", key: "mode" },
      { label: "Key", render: (x) => (x.has_key ? "set" : x.code === "DEFAULT" ? "legacy /tap" : "none") },
      { label: "Last seen", key: "last_seen" }, { label: "Firmware", key: "firmware" }, { label: "IP", key: "ip" },
      { label: "Queue", key: "queue_len" }, { label: "Active", render: (x) => (x.active ? "yes" : "no") },
      { label: "", render: (x) => h("span", {},
        x.mode === "KIOSK" ? h("button", { class: "btn small", onclick: async () => { if (await guard(() => api("POST", `/admin/devices/${x.id}/arm-timeout`))) toast(`${x.code}: next tap is a TIME OUT (15 s).`); } }, "Arm TIME OUT") : null,
        can("registrar") ? [h("button", { class: "btn small", onclick: () => editDevice(x, loadDevices) }, "Edit"),
          x.code !== "DEFAULT" ? h("button", { class: "btn small", onclick: () => rotateKey(x) }, "New key") : null] : null) }],
    r.items));
  };
  const loadTaps = async () => {
    const r = await guard(() => api("GET", "/admin/taps?limit=50" + (unknownOnly.checked ? "&unknown=1" : "")));
    if (!r || unchanged("taps" + unknownOnly.checked, r)) return;
    taps.replaceChildren(table([{ label: "Time", key: "received_at" }, { label: "Reader", key: "device" }, { label: "Card", key: "uid" },
      { label: "Name", key: "name" }, { label: "Result", render: (x) => pill(x.status) }, { label: "Code", key: "result_code" },
      { label: "", render: (x) => (x.result_code === "DENY_UNKNOWN" ? h("span", {},
        can("registrar") ? h("button", { class: "btn small", onclick: () => addStudent(loadTaps, x.uid) }, "Register student") : null,
        h("button", { class: "btn small", onclick: () => registerVisitor(loadTaps, x.uid) }, "Register visitor")) : "") }],
    r.items, "No taps yet."));
  };
  unknownOnly.onchange = loadTaps;
  view.replaceChildren(
    h("div", { class: "toolbar" }, h("span", { class: "muted" }, "Readers post taps with their own key. Taps on the legacy /tap route belong to DEFAULT."),
      h("span", { class: "spacer" }), can("registrar") ? h("button", { class: "btn primary", onclick: () => addDevice(loadDevices) }, "Add reader") : null),
    devs,
    h("div", { class: "toolbar", style: "margin-top:18px" }, h("strong", {}, "Recent taps"), h("label", {}, unknownOnly, " Unregistered cards only")),
    taps);
  await Promise.all([loadDevices(), loadTaps()]);
  S.timers.push(setInterval(loadTaps, 4000), setInterval(loadDevices, 15000));
});

const DEVICE_FIELDS = [
  { name: "code", label: "Code", required: true, help: "Short id, e.g. GATE-1" },
  { name: "name", label: "Name", required: true },
  { name: "location", label: "Location" },
  { name: "mode", kind: "choice", label: "Mode", choices: ["KIOSK", "IN", "OUT"], required: true,
    help: "KIOSK: taps time in; the TIME OUT button arms one time out. IN / OUT: an entrance or exit reader." }];

function firmwareSnippet(code, key) {
  return `const char* SERVER_BASE = "http://${location.hostname}:${location.port || 80}";\nconst char* DEVICE_CODE = "${code}";\nconst char* DEVICE_KEY  = "${key}";`;
}

async function addDevice(reload) {
  openModal("Add reader", await simpleForm(DEVICE_FIELDS, "Create", async (d) => {
    const r = await api("POST", "/admin/devices", d);
    reload();
    showSecret("Reader created", [`Put these lines in rfid_reader.ino for ${r.code}, then upload it to the ESP32:`],
      firmwareSnippet(r.code, r.device_key));
  }));
}

async function editDevice(x, reload) {
  const fields = [...DEVICE_FIELDS.slice(1), { name: "active", kind: "bool", label: "Active" }];
  openModal(`Edit ${x.code}`, await formFor(fields, x, "Save", async (d) => {
    await api("PATCH", `/admin/devices/${x.id}`, d);
    closeModal(); toast("Reader saved."); reload();
  }));
}

async function rotateKey(x) {
  if (!confirm(`Make a new key for ${x.code}? The reader stops working until its firmware has the new key.`)) return;
  const r = await guard(() => api("POST", `/admin/devices/${x.id}/rotate-key`));
  if (r) showSecret("New reader key", [`Update rfid_reader.ino for ${x.code}:`], firmwareSnippet(x.code, r.device_key));
}

page("announcements", "Announcements", "Communication", ["registrar", "teacher"], async (view) => {
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/announcements"));
    if (!r) return;
    out.replaceChildren(table([{ label: "Published", key: "published_at" }, { label: "Category", render: (x) => pill(x.category) },
      { label: "Title", key: "title" }, { label: "Message", key: "body", wrap: true },
      { label: "Audience", render: (x) => (x.section_name ? x.section_name : "Everyone") }, { label: "By", key: "author" },
      { label: "", render: (x) => (can("registrar") ? h("button", { class: "btn small danger", onclick: async () => {
        if (confirm("Remove it from the feed? Copies already in inboxes stay.") && await guard(() => api("DELETE", `/admin/announcements/${x.id}`))) load();
      } }, "Remove") : "") }], r.items));
  };
  view.replaceChildren(h("div", { class: "toolbar" }, h("span", { class: "muted" }, "Announcements go to every student's app inbox (or one section's)."),
    h("span", { class: "spacer" }), h("button", { class: "btn primary", onclick: () => compose(load) }, "New announcement")), out);
  await load();
});

async function compose(reload) {
  const teacher = S.staff.role === "teacher";
  openModal("New announcement", await simpleForm([
    { name: "category", kind: "choice", label: "Category", required: true, choices: teacher ? ["system"] : ["system", "emergency"],
      help: "Emergency notices ignore the students' notification preferences." },
    { name: "title", label: "Title", required: true, max_len: 80 },
    { name: "body", label: "Message", required: true, max_len: 500 },
    { name: "section_id", kind: "ref", ref: "sections", label: "Section", required: teacher, help: teacher ? "" : "Blank = everyone." },
    { name: "pinned", kind: "bool", label: "Pin to the top" }], "Publish", async (d) => {
    const r = await api("POST", "/admin/announcements", d);
    closeModal(); toast(`Sent to ${r.recipients} student${r.recipients === 1 ? "" : "s"}.`); reload();
  }));
}

page("excuses", "Excuse letters", "Communication", ["registrar", "teacher"], async (view) => {
  const status = h("select", {}, ["pending", "approved", "rejected", ""].map((s) => h("option", { value: s }, s || "All")));
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/excuses?status=" + status.value));
    if (!r) return;
    out.replaceChildren(table([{ label: "Date", key: "date" }, { label: "Student", key: "name" }, { label: "Student no.", key: "student_number" },
      { label: "Section", key: "section" }, { label: "Reason", key: "reason", wrap: true }, { label: "Status", render: (x) => pill(x.status) },
      { label: "Note", key: "review_note", wrap: true },
      { label: "", render: (x) => (x.status === "pending" ? h("span", {},
        h("button", { class: "btn small", onclick: () => review(x, "approved", load) }, "Approve"),
        h("button", { class: "btn small danger", onclick: () => review(x, "rejected", load) }, "Reject")) : "") }],
    r.items, "No excuse letters."));
  };
  status.onchange = load;
  view.replaceChildren(h("div", { class: "toolbar" }, status, h("span", { class: "muted" }, "Approved letters turn an absence into “excused”.")), out);
  await load();
});

async function review(x, status, reload) {
  const note = prompt(`${status === "approved" ? "Approve" : "Reject"} ${x.name}'s letter for ${x.date}. Note (optional):`, "");
  if (note === null) return;
  if (await guard(() => api("POST", `/admin/excuses/${x.id}/review`, { status, note }))) { toast("Done. The student was notified."); reload(); }
}

page("tickets", "Support tickets", "Communication", ["registrar", "teacher"], async (view) => {
  const status = h("select", {}, ["open", "answered", "closed", ""].map((s) => h("option", { value: s }, s || "All")));
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/tickets?status=" + status.value));
    if (!r) return;
    out.replaceChildren(table([{ label: "Sent", key: "created_at" }, { label: "Student", key: "name" }, { label: "Subject", key: "subject" },
      { label: "Message", key: "body", wrap: true }, { label: "Status", render: (x) => pill(x.status) }, { label: "Reply", key: "reply", wrap: true },
      { label: "", render: (x) => h("button", { class: "btn small", onclick: () => reply(x, load) }, "Reply") }], r.items, "No tickets."));
  };
  status.onchange = load;
  view.replaceChildren(h("div", { class: "toolbar" }, status), out);
  await load();
});

async function reply(x, reload) {
  openModal(`Reply to ${x.name}`, await simpleForm([
    { name: "reply", label: `Re: ${x.subject}`, required: true, max_len: 1000 },
    { name: "close", kind: "bool", label: "Close the ticket" }], "Send reply", async (d) => {
    await api("POST", `/admin/tickets/${x.id}/reply`, d);
    closeModal(); toast("Reply sent to the student's inbox."); reload();
  }));
}

page("reservations", "Library reservations", "Campus", ["registrar"], async (view) => {
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/library/reservations"));
    if (!r) return;
    const set = (x, s) => async () => { if (await guard(() => api("PATCH", `/admin/library/reservations/${x.id}`, { status: s }))) load(); };
    out.replaceChildren(table([{ label: "Requested", key: "created_at" }, { label: "Book", key: "title" }, { label: "Student", key: "name" },
      { label: "Student no.", key: "student_number" }, { label: "Status", render: (x) => pill(x.status) },
      { label: "", render: (x) => h("span", {},
        x.status === "reserved" ? h("button", { class: "btn small", onclick: set(x, "borrowed") }, "Lend") : null,
        x.status === "borrowed" ? h("button", { class: "btn small", onclick: set(x, "returned") }, "Returned") : null,
        x.status === "reserved" ? h("button", { class: "btn small danger", onclick: set(x, "cancelled") }, "Cancel") : null) }],
    r.items, "No reservations."));
  };
  view.replaceChildren(out);
  await load();
});

page("staff", "Staff accounts", "Administration", ["registrar", "teacher", "guard"], async (view) => {
  const out = h("div");
  const load = async () => {
    const r = await guard(() => api("GET", "/admin/staff"));
    if (!r) return;
    out.replaceChildren(table([{ label: "Username", key: "username" }, { label: "Name", key: "full_name" }, { label: "Role", key: "role" },
      { label: "Email", key: "email" }, { label: "Active", render: (x) => (x.active ? "yes" : "no") }, { label: "Last sign-in", key: "last_login" },
      { label: "", render: (x) => (can() ? h("span", {},
        h("button", { class: "btn small", onclick: () => editStaff(x, load) }, "Edit"),
        h("button", { class: "btn small", onclick: () => resetStaffPassword(x) }, "Reset password")) : "") }], r.items));
  };
  view.replaceChildren(h("div", { class: "toolbar" }, h("span", { class: "spacer" }),
    can() ? h("button", { class: "btn primary", onclick: () => addStaff(load) }, "Add staff") : null), out);
  await load();
});

const ROLE_CHOICE = { name: "role", kind: "choice", label: "Role", required: true, choices: ["admin", "registrar", "teacher", "guard"],
  help: "admin: everything · registrar: students, readers, reports · teacher: reports, assignments, section announcements · guard: readers, visitors" };

async function addStaff(reload) {
  openModal("Add staff", await simpleForm([{ name: "username", label: "Username", required: true },
    { name: "full_name", label: "Full name", required: true }, ROLE_CHOICE,
    { name: "password", label: "Temporary password (8+ characters)", required: true }, { name: "email", label: "Email" },
    { name: "phone", label: "Phone" }], "Create", async (d) => {
    await api("POST", "/admin/staff", d); closeModal(); toast("Staff account created."); dropRefs(); reload();
  }));
}

async function editStaff(x, reload) {
  openModal(`Edit ${x.username}`, await formFor([{ name: "full_name", label: "Full name", required: true }, ROLE_CHOICE,
    { name: "email", label: "Email" }, { name: "phone", label: "Phone" }, { name: "active", kind: "bool", label: "Active" }], x, "Save", async (d) => {
    await api("PATCH", `/admin/staff/${x.id}`, d); closeModal(); toast("Saved."); dropRefs(); reload();
  }));
}

async function resetStaffPassword(x) {
  const pw = prompt(`New password for ${x.username} (8+ characters):`);
  if (pw && await guard(() => api("PATCH", `/admin/staff/${x.id}`, { password: pw }))) toast("Password changed. Their sessions were signed out.");
}

page("settings", "Attendance settings", "Administration", null, async (view) => {
  const r = await guard(() => api("GET", "/admin/settings"));
  if (!r) return;
  const s = r.settings;
  const days = (s.school_days || "").split(",");
  const events = (s.sms_events || "").split(",");
  const editable = can();
  const form = h("form", { class: "form panel", style: "max-width:560px" },
    h("div", { class: "row" },
      h("label", {}, "School starts", h("input", { type: "time", name: "school_start", value: s.school_start, disabled: !editable })),
      h("label", {}, "Late after (minutes)", h("input", { type: "number", min: 0, max: 240, name: "late_after_minutes", value: s.late_after_minutes, disabled: !editable }))),
    h("div", { class: "row" },
      h("label", {}, "Daily cutoff", h("input", { type: "time", name: "cutoff", value: s.cutoff, disabled: !editable }),
        h("span", { class: "help muted" }, "At the cutoff, open records are flagged and absences recorded.")),
      h("label", {}, "Visitor limit (hours)", h("input", { type: "number", step: "0.25", min: 0.25, max: 24, name: "visitor_limit_hours", value: s.visitor_limit_hours, disabled: !editable }))),
    h("label", {}, "School days", h("div", {}, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((d, i) =>
      h("label", { style: "display:inline-flex;gap:4px;margin-right:10px;color:var(--text)" },
        h("input", { type: "checkbox", name: "day", value: i + 1, checked: days.includes(String(i + 1)), disabled: !editable }), d)))),
    h("label", { style: "display:flex;gap:8px;align-items:center;color:var(--text)" },
      h("input", { type: "checkbox", name: "notify_absences", checked: s.notify_absences === "1", disabled: !editable }), "Tell students in the app when they are marked absent"),
    h("label", {}, "Guardian SMS for", h("div", {}, [["in", "Time in"], ["out", "Time out"], ["absent", "Absence"]].map(([v, l]) =>
      h("label", { style: "display:inline-flex;gap:4px;margin-right:10px;color:var(--text)" },
        h("input", { type: "checkbox", name: "sms", value: v, checked: events.includes(v), disabled: !editable }), l)))),
    h("p", { class: "muted small" }, "Last day closed: " + dash(s.last_close_date)),
    editable ? h("div", { class: "actions" }, h("button", { class: "btn primary", type: "submit" }, "Save settings")) :
      h("p", { class: "muted" }, "Only an admin can change these."));
  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const f = form.elements;
    const body = { school_start: f.school_start.value, late_after_minutes: f.late_after_minutes.value, cutoff: f.cutoff.value,
      visitor_limit_hours: f.visitor_limit_hours.value, notify_absences: f.notify_absences.checked ? "1" : "0",
      school_days: [...form.querySelectorAll("input[name=day]:checked")].map((x) => x.value).join(","),
      sms_events: [...form.querySelectorAll("input[name=sms]:checked")].map((x) => x.value).join(",") };
    if (await guard(() => api("PUT", "/admin/settings", body))) toast("Settings saved.");
  });
  const closeDate = h("input", { type: "date", value: today() });
  view.replaceChildren(form, editable ? h("div", { class: "panel", style: "max-width:560px" }, h("h3", {}, "Close a day now"),
    h("p", { class: "muted small" }, "Normally automatic at the cutoff. Safe to repeat: flags open records and records absences."),
    h("div", { class: "toolbar" }, closeDate, h("button", { class: "btn", onclick: async () => {
      const r = await guard(() => api("POST", "/admin/jobs/close-day", { date: closeDate.value }));
      if (r) toast(`${r.date}: ${r.missing_time_out.length} missing time out, ${r.absent.length} absent.`);
    } }, "Close day"))) : "");
});

page("sms", "SMS outbox", "Administration", ["registrar"], async (view) => {
  const r = await guard(() => api("GET", "/admin/sms"));
  if (!r) return;
  view.replaceChildren(h("p", { class: "muted" }, `Provider: ${r.provider}. Set SMS_PROVIDER in project/.env to send real texts.`),
    table([{ label: "Queued", key: "created_at" }, { label: "Student", key: "student" }, { label: "Guardian", key: "guardian" },
      { label: "Phone", key: "phone" }, { label: "Message", key: "body", wrap: true }, { label: "Status", render: (x) => pill(x.status) },
      { label: "Error", key: "error", wrap: true }], r.items, "No messages yet. Add guardians to students to send texts."));
});

page("audit", "Audit log", "Administration", [], async (view) => {
  const r = await guard(() => api("GET", "/admin/audit"));
  if (!r) return;
  view.replaceChildren(table([{ label: "When", key: "at" }, { label: "Who", render: (x) => x.username || "admin key" },
    { label: "Action", key: "action" }, { label: "Detail", key: "detail", wrap: true }], r.items));
});

// Generic pages for every table resource the server publishes.
function resourcePage(res) {
  return async (view, params) => {
    const search = res.search ? h("input", { placeholder: "Search" }) : null;
    const filterEls = {};
    const toolbar = h("div", { class: "toolbar" });
    if (search) toolbar.append(search);
    for (const fname of res.filters) {
      const f = res.fields.find((x) => x.name === fname) || { name: fname, kind: "text", label: fname };
      let el;
      if (f.kind === "ref") {
        const opts = await guard(() => refOptions(f.ref)) || [];
        el = h("select", {}, h("option", { value: "" }, "Any " + f.label.toLowerCase()), opts.map((o) => h("option", { value: o.value }, o.label)));
      } else if (f.kind === "choice") {
        el = h("select", {}, h("option", { value: "" }, "Any " + f.label.toLowerCase()), f.choices.map((c) => h("option", { value: c }, String(c))));
      } else el = h("input", { placeholder: f.label });
      if (params && params[fname] !== undefined) el.value = params[fname];
      filterEls[fname] = el;
      toolbar.append(el);
    }
    const writable = can(...res.write_roles);
    toolbar.append(h("span", { class: "spacer" }), writable ? h("button", { class: "btn primary", onclick: () => edit(null) }, "New") : null);
    const out = h("div");
    const cols = res.fields.filter((f) => f.list_column !== false);
    const refMaps = {};
    for (const f of cols.filter((x) => x.kind === "ref")) {
      const opts = await guard(() => refOptions(f.ref)) || [];
      refMaps[f.name] = Object.fromEntries(opts.map((o) => [String(o.value), o.label]));
    }
    const show = (f, v) => {
      if (v === null || v === undefined || v === "") return "—";
      if (f.kind === "ref") return refMaps[f.name][String(v)] || "#" + v;
      if (f.kind === "bool") return v ? "yes" : "no";
      if (f.kind === "list") return v.join(", ");
      if (f.name === "weekday" && S.meta.weekdays) return S.meta.weekdays[v] || v;
      if (f.name === "status" || f.name === "kind") return pill(v);
      return String(v);
    };
    const load = async () => {
      const qs = new URLSearchParams();
      if (search && search.value) qs.set("q", search.value);
      for (const [k, el] of Object.entries(filterEls)) if (el.value) qs.set(k, el.value);
      const r = await guard(() => api("GET", `/admin/${res.name}?` + qs));
      if (!r) return;
      out.replaceChildren(table([...cols.map((f) => ({ label: f.label, render: (x) => show(f, x[f.name]) })),
        { label: "", render: (x) => (writable ? h("span", {},
          h("button", { class: "btn small", onclick: () => edit(x) }, "Edit"),
          h("button", { class: "btn small danger", onclick: () => remove(x) }, res.soft_delete ? "Hide" : "Delete")) : "") }],
      r.items, `No ${res.label.toLowerCase()} yet.`));
    };
    const edit = async (item) => {
      const values = item ? { ...item } : Object.fromEntries(Object.entries(filterEls).filter(([, el]) => el.value).map(([k, el]) => [k, el.value]));
      openModal((item ? "Edit " : "New ") + res.label.replace(/s$/, "").toLowerCase(), await formFor(res.fields, values, item ? "Save" : "Create", async (d) => {
        if (item) await api("PATCH", `/admin/${res.name}/${item.id}`, d);
        else await api("POST", `/admin/${res.name}`, d);
        closeModal(); toast("Saved."); dropRefs(); load();
      }));
    };
    const remove = async (item) => {
      if (!confirm(res.soft_delete ? "Hide this from students?" : "Delete this permanently?")) return;
      if (await guard(() => api("DELETE", `/admin/${res.name}/${item.id}`))) { toast("Done."); dropRefs(); load(); }
    };
    if (search) search.oninput = () => { clearTimeout(search._t); search._t = setTimeout(load, 300); };
    Object.values(filterEls).forEach((el) => (el.onchange = load));
    view.replaceChildren(toolbar, out);
    await load();
  };
}

// ------------------------------------------------------------------ shell + routing
const GROUP_ORDER = ["Overview", "Attendance", "People", "School", "Communication", "Campus", "Support", "Administration"];

function allPages() {
  const generic = Object.values(S.meta.resources).map((r) => ({
    id: "r-" + r.name, resource: r.name, title: r.label, group: r.group === "People" ? "People" : r.group,
    roles: r.read_roles, render: resourcePage(r) }));
  return [...PAGES, ...generic].filter((p) => p.roles === null || can(...p.roles));
}

function go(id, params) {
  const target = allPages().find((p) => p.id === id || p.resource === id);
  if (!target) return;
  const qs = params ? "?" + new URLSearchParams(params) : "";
  location.hash = "#/" + target.id + qs;
}

function renderNav(pages, active, badges) {
  const nav = $("#nav");
  nav.replaceChildren();
  for (const g of GROUP_ORDER) {
    const items = pages.filter((p) => p.group === g);
    if (!items.length) continue;
    nav.append(h("div", { class: "group" }, g));
    for (const p of items) {
      nav.append(h("a", { href: "#/" + p.id, class: p.id === active ? "active" : null },
        p.title, badges[p.id] ? h("span", { class: "badge" }, badges[p.id]) : null));
    }
  }
}

async function route() {
  S.timers.forEach(clearInterval);
  S.timers = [];
  Object.keys(lastSeen).forEach((k) => delete lastSeen[k]);
  closeModal();
  $("#sidebar").classList.remove("open");
  const pages = allPages();
  const [id, query] = (location.hash.replace(/^#\//, "") || "dashboard").split("?");
  const p = pages.find((x) => x.id === id) || pages[0];
  const params = Object.fromEntries(new URLSearchParams(query || ""));
  const counts = (await guard(() => api("GET", "/admin/dashboard")) || { pending: {} }).pending;
  renderNav(pages, p.id, { excuses: counts.excuses, tickets: counts.tickets, reservations: counts.reservations,
    "r-lost_found": counts.claims });
  $("#pageTitle").textContent = p.title;
  document.title = p.title + " · PULSE Admin";
  const view = $("#view");
  view.replaceChildren(h("p", { class: "muted" }, "Loading…"));
  dropRefs();
  await p.render(view, params);
}

async function boot() {
  S.token = storeGet(TOKEN_KEY);
  if (!S.token) return showLogin();
  try {
    S.meta = await api("GET", "/admin/meta");
    S.staff = S.meta.staff;
  } catch { return showLogin(); }
  $("#login").hidden = true;
  $("#app").hidden = false;
  $("#whoami").textContent = `${S.staff.full_name} · ${S.staff.role}`;
  await route();
}

function showLogin() {
  $("#app").hidden = true;
  $("#login").hidden = false;
  $("#loginForm").elements.username.focus();
}

async function signOut(expired = false) {
  if (!expired && S.token) { try { await api("POST", "/admin/auth/logout"); } catch { /* already gone */ } }
  S.token = null; S.staff = null; S.meta = null;
  storeSet(TOKEN_KEY, null);
  S.timers.forEach(clearInterval); S.timers = [];
  showLogin();
  if (expired) toast("Your session ended. Please sign in again.", true);
}

$("#loginForm").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const f = ev.target.elements;
  const err = $("#loginError");
  err.hidden = true;
  try {
    const r = await api("POST", "/admin/auth/login", { username: f.username.value.trim(), password: f.password.value });
    S.token = r.token;
    storeSet(TOKEN_KEY, r.token);
    f.password.value = "";
    await boot();
  } catch (e) { err.textContent = e.message; err.hidden = false; }
});
$("#logoutBtn").onclick = () => signOut();
$("#passwordBtn").onclick = async () => {
  if (!S.staff || S.staff.id === null) return toast("The admin key has no password.", true);
  openModal("Change your password", await simpleForm([
    { name: "current_password", label: "Current password", required: true },
    { name: "new_password", label: "New password (8+ characters)", required: true }], "Change password", async (d) => {
    await api("POST", "/admin/auth/password", d); closeModal(); toast("Password changed.");
  }));
  $("#modalBody").querySelectorAll("input").forEach((i) => (i.type = "password"));
};
$("#modalClose").onclick = closeModal;
$("#modal").addEventListener("click", (ev) => { if (ev.target.id === "modal") closeModal(); });
document.addEventListener("keydown", (ev) => { if (ev.key === "Escape") closeModal(); });
$("#menuBtn").onclick = () => $("#sidebar").classList.toggle("open");
window.addEventListener("hashchange", () => { if (S.meta) route(); });
boot();
