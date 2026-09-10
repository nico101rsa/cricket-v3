"""Generate the PWA icons (a cricket ball on green) with no dependencies."""
import struct
import sys
import zlib


def png(width, height, pixel):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


def icon(size):
    cx = cy = size / 2
    r = size * 0.33
    def pixel(x, y):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        d = (dx * dx + dy * dy) ** 0.5
        if d <= r:
            # seam: a band across the ball
            if abs(dy - dx * 0.35) < size * 0.018 and abs(dx) < r * 0.92:
                return (255, 240, 220)
            shade = max(0.0, 1 - d / r) * 0.35
            return (int(180 + 60 * shade), int(30 + 30 * shade), int(40 + 20 * shade))
        if d <= r + size * 0.02:
            return (120, 20, 30)
        return (29, 107, 58)
    return png(size, size, pixel)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'static'
    for s in (180, 192, 512):
        with open(f'{out}/icon-{s}.png', 'wb') as f:
            f.write(icon(s))
    print('icons written')
