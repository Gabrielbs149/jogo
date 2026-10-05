"""Manda código para o Blender aberto (complemento MCP for Blender ligado, porta 9876).
Cliente mínimo do complemento MCP for Blender (porta 9876): manda um comando JSON e imprime a resposta.
Uso: python bl.py info | python bl.py code arquivo.py | python bl.py shot saida.png
"""
import json, socket, sys


def send(cmd):
    with socket.create_connection(("127.0.0.1", 9876), timeout=900) as s:
        s.sendall(json.dumps(cmd).encode("utf-8"))
        buf = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
            try:
                return json.loads(buf.decode("utf-8"))
            except json.JSONDecodeError:
                continue
    return json.loads(buf.decode("utf-8"))


mode = sys.argv[1]
if mode == "info":
    r = send({"type": "get_scene_info", "params": {}})
elif mode == "code":
    code = open(sys.argv[2], encoding="utf-8").read()
    r = send({"type": "execute_code", "params": {"code": code}})
elif mode == "shot":
    r = send({"type": "get_viewport_screenshot", "params": {"max_size": 900, "filepath": sys.argv[2], "format": "png"}})
else:
    raise SystemExit("modo desconhecido")
out = json.dumps(r, ensure_ascii=False)
print(out[:3000])
