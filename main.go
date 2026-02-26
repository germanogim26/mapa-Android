package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"net/http"
	"strings"
	"time"
)

//go:embed static templates_teste equipamentos.json
var content embed.FS

type Equipamento struct {
	Arquivo string  `json:"arquivo"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
}

var INDICE map[string]Equipamento

func main() {
	data, _ := content.ReadFile("equipamentos.json")
	json.Unmarshal(data, &INDICE)

	staticFS, _ := fs.Sub(content, "static")
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		file, _ := content.ReadFile("templates_teste/index_teste.html")
		output := strings.ReplaceAll(string(file), "{{ t }}", fmt.Sprintf("%d", time.Now().Unix()))
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, output)
	})

	http.HandleFunc("/multifilar", func(w http.ResponseWriter, r *http.Request) {
		file, _ := content.ReadFile("templates_teste/multifilar_teste.html")
		output := strings.ReplaceAll(string(file), "{{ t }}", fmt.Sprintf("%d", time.Now().Unix()))
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, output)
	})

	http.HandleFunc("/api/tiles", func(w http.ResponseWriter, r *http.Request) {
		foco := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("foco")))
		info, existe := INDICE[foco]
		
		if !existe {
			partes := strings.Split(foco, "-")
			if len(partes) >= 2 {
				sigla := partes[1]
				numero := partes[len(partes)-1]
				for key, val := range INDICE {
					if strings.Contains(key, sigla) && strings.Contains(key, numero) {
						info = val
						existe = true
						break
					}
				}
			}
		}

		w.Header().Set("Content-Type", "application/json")
		if !existe {
			w.WriteHeader(404)
			json.NewEncoder(w).Encode(map[string]string{"erro": "nao encontrado"})
			return
		}
		cidade := strings.Replace(strings.ToLower(info.Arquivo), ".dxf", "", 1)
		json.NewEncoder(w).Encode(map[string]interface{}{"x": info.X, "y": info.Y, "cidade": cidade})
	})

	// Rota de alta performance: Apenas entrega os arquivos, sem escrever nada no terminal
	http.HandleFunc("/api/tiles_infinito", func(w http.ResponseWriter, r *http.Request) {
		cidade := strings.ToLower(r.URL.Query().Get("cidade"))
		tx, ty := r.URL.Query().Get("tx"), r.URL.Query().Get("ty")
		path := fmt.Sprintf("static/tiles/%s/t_%s_%s.txt", cidade, tx, ty)
		
		w.Header().Set("Content-Type", "application/json")
		data, err := content.ReadFile(path)
		if err != nil {
			json.NewEncoder(w).Encode(map[string]string{"svg": ""})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"svg": string(data)})
	})

	fmt.Println("🚀 MOTOR DE PRODUÇÃO ONLINE: Silencioso e Rápido")
	http.ListenAndServe(":5002", nil)
}
