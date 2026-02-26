package main

import (
	"fmt"
	"os"
)

func main() {
	cwd, _ := os.Getwd()
	fmt.Printf("📂 Diretorio atual: %s\n", cwd)

	path := "templates_teste/index_teste.html"
	_, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Printf("❌ ERRO: O arquivo '%s' NAO foi encontrado aqui!\n", path)
		} else {
			fmt.Printf("❌ ERRO DE PERMISSAO: %v\n", err)
		}
	} else {
		fmt.Printf("✅ SUCESSO: O arquivo '%s' foi encontrado e esta acessivel!\n", path)
	}
}
