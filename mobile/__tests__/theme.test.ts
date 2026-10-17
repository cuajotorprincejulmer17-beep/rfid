import { contrastRatio } from '../src/theme/contrast';
import { mix } from '../src/theme/color';
import { palettes } from '../src/theme/tokens';

describe('colour helpers', () => {
  it('keeps both endpoints when blending violet borders', () => {
    expect(mix('#000000', '#FFFFFF', 0)).toBe('#000000');
    expect(mix('#000000', '#FFFFFF', 1)).toBe('#ffffff');
  });
});

describe('theme contrast (WCAG AA, 4.5:1 for text)', () => {
  for (const p of Object.values(palettes)) {
    describe(p.name, () => {
      it('body text on background and surfaces', () => {
        expect(contrastRatio(p.text, p.bg)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(p.text, p.surface)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(p.text, p.surfaceAlt)).toBeGreaterThanOrEqual(4.5);
      });
      it('muted text on background and surfaces', () => {
        expect(contrastRatio(p.textMuted, p.bg)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(p.textMuted, p.surface)).toBeGreaterThanOrEqual(4.5);
        expect(contrastRatio(p.textMuted, p.surfaceAlt)).toBeGreaterThanOrEqual(4.5);
      });
      it('text on primary buttons', () => {
        expect(contrastRatio(p.onPrimary, p.primary)).toBeGreaterThanOrEqual(4.5);
      });
      it('status colors readable on surface', () => {
        for (const c of [p.success, p.warning, p.danger, p.accent]) {
          expect(contrastRatio(c, p.surface)).toBeGreaterThanOrEqual(4.5);
        }
      });
    });
  }
});
