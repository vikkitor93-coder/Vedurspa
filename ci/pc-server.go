package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"mime"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const startPort = 8765

func main() {
	exe, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	root := filepath.Join(filepath.Dir(exe), "web")
	if _, err := os.Stat(filepath.Join(root, "index.html")); err != nil {
		log.Fatalf("Web files not found next to the launcher: %v", err)
	}

	mux := http.NewServeMux()
	client := &http.Client{Timeout: 35 * time.Second}

	mux.HandleFunc("/api/vedur", func(w http.ResponseWriter, r *http.Request) {
		raw := r.URL.Query().Get("url")
		target, err := url.Parse(raw)
		if err != nil || target.Scheme != "https" || (target.Hostname() != "www.vedur.is" && target.Hostname() != "vedur.is") {
			http.Error(w, "Invalid Veðurstofa URL", http.StatusBadRequest)
			return
		}
		req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, target.String(), nil)
		if err != nil {
			http.Error(w, "Request error", 500)
			return
		}
		req.Header.Set("User-Agent", "Vedurspa-PC/1.3")
		req.Header.Set("Accept", r.Header.Get("Accept"))
		resp, err := client.Do(req)
		if err != nil {
			http.Error(w, "Veðurstofa unavailable: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		for _, h := range []string{"Content-Type", "Cache-Control", "Last-Modified", "ETag"} {
			if v := resp.Header.Get(h); v != "" {
				w.Header().Set(h, v)
			}
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.WriteHeader(resp.StatusCode)
		_, _ = io.Copy(w, resp.Body)
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		clean := filepath.Clean(strings.TrimPrefix(r.URL.Path, "/"))
		if clean == "." {
			clean = "index.html"
		}
		full := filepath.Join(root, clean)
		rootClean, _ := filepath.Abs(root)
		fullClean, _ := filepath.Abs(full)
		if !strings.HasPrefix(strings.ToLower(fullClean), strings.ToLower(rootClean+string(os.PathSeparator))) && fullClean != rootClean {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}
		info, err := os.Stat(fullClean)
		if err != nil || info.IsDir() {
			fullClean = filepath.Join(root, "index.html")
		}
		if ext := filepath.Ext(fullClean); ext != "" {
			if ct := mime.TypeByExtension(ext); ct != "" {
				w.Header().Set("Content-Type", ct)
			}
		}
		w.Header().Set("Cache-Control", "no-cache")
		http.ServeFile(w, r, fullClean)
	})

	var ln net.Listener
	var addr string
	for port := startPort; port < startPort+30; port++ {
		addr = fmt.Sprintf("127.0.0.1:%d", port)
		ln, err = net.Listen("tcp", addr)
		if err == nil {
			break
		}
	}
	if ln == nil {
		log.Fatal("Could not open a local port for Veðurspá")
	}

	page := "http://" + addr + "/"
	fmt.Println("Veðurspá PC is running at", page)
	fmt.Println("Close this window to stop the local app server.")

	go func() {
		time.Sleep(450 * time.Millisecond)
		openBrowser(page)
	}()

	srv := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	if err := srv.Serve(ln); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}

func openBrowser(page string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.CommandContext(ctx, "rundll32", "url.dll,FileProtocolHandler", page)
	case "darwin":
		cmd = exec.CommandContext(ctx, "open", page)
	default:
		cmd = exec.CommandContext(ctx, "xdg-open", page)
	}
	_ = cmd.Start()
}
