import os, json, time
from flask import Flask, render_template, request, jsonify

# Configuramos este app para buscar os HTMLs na pasta 'templates_teste'
app = Flask(__name__, template_folder='templates_teste', static_folder='static')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TILE_DIR = os.path.join(BASE_DIR, 'static', 'tiles')
INDICE_PATH = os.path.join(BASE_DIR, 'equipamentos.json')

INDICE = {}
if os.path.exists(INDICE_PATH):
    with open(INDICE_PATH, 'r', encoding='utf-8') as f:
        INDICE = json.load(f)

@app.route('/')
def index():
    return render_template('index_teste.html', t=time.time())

@app.route('/multifilar')
def multifilar():
    return render_template('multifilar_teste.html', t=time.time())

@app.route('/api/tiles_infinito')
def get_tiles_infinito():
    cidade = request.args.get('cidade', '').lower()
    tx = request.args.get('tx')
    ty = request.args.get('ty')
    p = os.path.join(TILE_DIR, cidade, f"t_{tx}_{ty}.txt")
    if os.path.exists(p):
        with open(p, 'r', encoding='utf-8') as f:
            return jsonify({"svg": f.read()})
    return jsonify({"svg": ""})

@app.route('/api/tiles')
def get_tiles_antigo():
    foco = request.args.get('foco', '').upper().strip()
    
    # PLANO A: Busca exata (Ex: CTO-ETA-0012 ou CTO-LJO-0712)
    info = INDICE.get(foco)
    
    # PLANO B: Filtra pela cidade e tenta o nome curto
    if not info:
        partes = foco.split('-')
        
        if len(partes) >= 3:
            tipo = partes[0]      
            sigla = partes[1]     
            numero = partes[-1]   
            foco_curto = f"{tipo}-{numero}" 
            
            mapa_cidades = {
                'ETA': 'estrela',
                'LJO': 'lajeado'
            }
            
            cidade_alvo = mapa_cidades.get(sigla, sigla.lower())
            candidato = INDICE.get(foco_curto)
            
            # TRAVA DE SEGURANÇA:
            if candidato:
                arquivo_dxf = candidato.get('arquivo', '').lower()
                if cidade_alvo in arquivo_dxf or sigla.lower() in arquivo_dxf:
                    info = candidato 

    if not info: 
        return jsonify({"erro": "Nao encontrado"}), 404
        
    cidade = info.get('arquivo', '').replace('.dxf', '').lower()
    return jsonify({"x": info.get('x'), "y": info.get('y'), "cidade": cidade})

if __name__ == '__main__':
    print("🔬 LABORATÓRIO ATIVO NA PORTA 5001")
    app.run(host='0.0.0.0', port=5001, debug=True, use_reloader=False)
