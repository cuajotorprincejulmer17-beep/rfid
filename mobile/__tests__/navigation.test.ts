import { MENU } from '../src/navigation/menu';
import { handleBack, overlayReducer } from '../src/navigation/overlay';
import { CORE_ITEMS, ITEM_W, fanPositions } from '../src/navigation/pulseCore';
import { IMPLEMENTED_STACK, IMPLEMENTED_TABS, Dest } from '../src/navigation/types';

const exists = (d: Dest) =>
  'tab' in d ? IMPLEMENTED_TABS.includes(d.tab) : IMPLEMENTED_STACK.includes(d.stack);

describe('overlay state and Android Back', () => {
  it('Back closes an open More overlay first and reports it handled', () => {
    expect(handleBack('more')).toEqual({ state: 'none', handled: true });
  });
  it('Back closes the Pulse Core fan first', () => {
    expect(handleBack('core')).toEqual({ state: 'none', handled: true });
  });
  it('Back with no overlay is left to normal navigation', () => {
    expect(handleBack('none')).toEqual({ state: 'none', handled: false });
  });
  it('opening and closing overlays never creates navigation state', () => {
    // The reducer only knows overlay state; it has no route or history input at all.
    let s = overlayReducer('none', { type: 'openMore' });
    expect(s).toBe('more');
    s = overlayReducer(s, { type: 'close' });
    expect(s).toBe('none');
  });
  it('Pulse Core is separate from More and acts as the close control while an overlay is open', () => {
    expect(overlayReducer('none', { type: 'toggleCore' })).toBe('core');
    expect(overlayReducer('core', { type: 'toggleCore' })).toBe('none');
    expect(overlayReducer('more', { type: 'toggleCore' })).toBe('none');
    expect(overlayReducer('none', { type: 'openMore' })).not.toBe(overlayReducer('none', { type: 'openCore' }));
  });
});

describe('More menu integrity', () => {
  const tiles = MENU.flatMap((g) => g.tiles);
  it('every tile is either a real destination or disabled with a reason', () => {
    for (const t of tiles) {
      if (t.dest) expect(exists(t.dest)).toBe(true);
      else expect(t.reason && t.reason.length > 0).toBe(true);
    }
  });
  it('keeps Academic, Campus and Personal groups and includes Study Space (Notes, Review)', () => {
    const titles = MENU.map((g) => g.title);
    expect(titles).toEqual(expect.arrayContaining(['Academic', 'Campus', 'Personal', 'Study Space']));
    expect(tiles.map((t) => t.label)).toEqual(expect.arrayContaining(['Notes', 'Review']));
  });
  it('does not include features with no school backend as working, nor the Financial group', () => {
    expect(titles()).not.toContain('Financial');
    for (const l of ['Digital ID', 'Room Finder', 'Lost & Found']) {
      expect(tiles.find((t) => t.label === l)?.dest).toBeUndefined();
    }
  });
  function titles() {
    return MENU.map((g) => g.title);
  }
});

describe('Pulse Core fan', () => {
  it('targets only implemented screens (or the separate More overlay)', () => {
    for (const i of CORE_ITEMS) if (i.action !== 'more') expect(exists(i.action)).toBe(true);
    expect(CORE_ITEMS.some((i) => i.action === 'more')).toBe(true);
  });
  it('fits inside a narrow 320dp-wide screen', () => {
    for (const p of fanPositions(CORE_ITEMS.length)) {
      expect(Math.abs(p.x) + ITEM_W / 2).toBeLessThanOrEqual(160);
    }
  });
  it('arranges items left to right without overlap', () => {
    const xs = fanPositions(CORE_ITEMS.length).map((p) => p.x);
    for (let i = 1; i < xs.length; i++) expect(xs[i]).toBeGreaterThan(xs[i - 1]);
  });
});
