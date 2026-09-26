import json
import os
import sys

from lottie.exporters.cairo import export_png
from lottie.importers.core import import_tgs


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: tgs_to_frames.py input.tgs out_dir", file=sys.stderr)
        return 2

    source = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    animation = import_tgs(source)
    start = int(round(float(animation.in_point)))
    end = int(round(float(animation.out_point)))
    if end < start:
        end = start

    fps = float(animation.frame_rate or 30)
    if fps <= 0:
        fps = 30

    count = 0
    for frame in range(start, end + 1):
        path = os.path.join(out_dir, f"frame_{count:04d}.png")
        export_png(animation, path, frame=frame)
        count += 1

    if count < 1:
        print("no_frames", file=sys.stderr)
        return 1

    json.dump({"fps": fps, "count": count}, sys.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
