"""Local-only preview of the actual Godot Web export. Python standard library."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import webbrowser


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--no-browser', action='store_true')
    parser.add_argument('--port', type=int, default=8060)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'builds' / 'web'
    if not all((root / ('index.' + ext)).is_file() for ext in ('html', 'js', 'wasm', 'pck')):
        print('缺少完整 Web 导出文件，请先运行 export_web.cmd。', flush=True)
        return 1
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(root)))
    except OSError as error:
        print(f'无法启动预览服务：{error}\n端口可能已占用，请关闭旧预览窗口后再试。', flush=True)
        return 1
    url = f'http://127.0.0.1:{args.port}/'
    print(f'网页预览：{url}\n请保持本窗口开启。关闭窗口或按 Ctrl+C 停止。', flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
