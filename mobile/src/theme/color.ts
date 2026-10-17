/** Blend two hexadecimal colours for restrained borders and violet highlights. */
export function mix(a: string, b: string, amount: number): string {
  const parse = (value: string) => Number.parseInt(value, 16);
  const clamp = Math.max(0, Math.min(1, amount));
  const channel = (offset: number) => Math.round(parse(a.slice(offset, offset + 2)) * (1 - clamp) + parse(b.slice(offset, offset + 2)) * clamp)
    .toString(16)
    .padStart(2, '0');
  return `#${channel(1)}${channel(3)}${channel(5)}`;
}
