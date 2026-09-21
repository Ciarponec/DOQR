// Run from the repository root: go run scripts/check_auth_email_templates.go
// Uses the same standard html/template renderer as Supabase Auth.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"html/template"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"unicode/utf16"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	outputDir := flag.String("output-dir", "", "optional directory for rendered language previews")
	flag.Parse()
	config, err := os.ReadFile("supabase/config.toml")
	must(err)
	if *outputDir != "" {
		must(os.MkdirAll(*outputDir, 0755))
	}
	cases := []struct {
		name     string
		saved    any
		redirect string
		want     string
	}{
		{"legacy", nil, "", "tr"},
		{"missing-language", "", "com.doqr.app://auth/callback", "tr"},
		{"unknown-language", "xx", "", "tr"},
		{"malformed-metadata", 42, "", "tr"},
		{"short-redirect", "en", "x", "en"},
		{"unknown-redirect-language", "ru", "https://example.com/?email_language=xx", "ru"},
	}
	for _, lang := range []string{"tr", "en", "ru"} {
		cases = append(cases, struct {
			name           string
			saved          any
			redirect, want string
		}{
			"metadata-" + lang, lang, "", lang,
		}, struct {
			name           string
			saved          any
			redirect, want string
		}{
			"native-" + lang, "ru", "com.doqr.app://auth/callback?email_language=" + lang, lang,
		}, struct {
			name           string
			saved          any
			redirect, want string
		}{
			"web-" + lang, "en", "https://example.com/app/?email_language=" + lang, lang,
		}, struct {
			name           string
			saved          any
			redirect, want string
		}{
			"web-query-" + lang, "tr", "https://example.com/app/?next=doors&email_language=" + lang, lang,
		})
	}
	subjects := map[string]map[string]string{
		"confirmation": {"tr": "DOQR: E-posta onayı", "en": "DOQR: Verify email", "ru": "DOQR: Подтверждение"},
		"recovery":     {"tr": "DOQR: Parola yenile", "en": "DOQR: Reset password", "ru": "DOQR: Сброс пароля"},
	}
	markers := map[string]string{"tr": "DİJİTAL ZİL", "en": "DIGITAL DOORBELL", "ru": "ЦИФРОВОЙ ДВЕРНОЙ ЗВОНОК"}
	checks := 0
	for _, name := range []string{"confirmation", "recovery"} {
		raw, err := os.ReadFile(filepath.Join("supabase", "templates", name+".html"))
		must(err)
		body := template.Must(template.New(name).Parse(string(raw)))
		re := regexp.MustCompile(`(?m)\[auth\.email\.template\.` + name + `\]\r?\nsubject = '([^\r\n]+)'`)
		match := re.FindStringSubmatch(string(config))
		if len(match) != 2 {
			panic("Missing subject: " + name)
		}
		// The hosted dashboard limits the raw subject template to 255 JS characters.
		if len(utf16.Encode([]rune(match[1]))) > 255 {
			panic("Subject exceeds hosted dashboard limit: " + name)
		}
		subject := template.Must(template.New("subject").Parse(match[1]))
		for _, tc := range cases {
			data := map[string]any{
				"Data":            map[string]any{"language": tc.saved},
				"RedirectTo":      tc.redirect,
				"SiteURL":         "https://example.com/app/",
				"ConfirmationURL": "https://example.com/verify?token=preview&type=signup",
			}
			var rendered, renderedSubject bytes.Buffer
			must(body.Execute(&rendered, data))
			must(subject.Execute(&renderedSubject, data))
			html := rendered.String()
			if renderedSubject.String() != subjects[name][tc.want] {
				panic(fmt.Sprintf("%s/%s: unexpected subject %q", name, tc.name, renderedSubject.String()))
			}
			if !strings.Contains(html, `lang="`+tc.want+`"`) ||
				strings.Contains(html, "{{") || strings.Contains(html, "TR · EN · RU") {
				panic(name + "/" + tc.name + ": unresolved or mixed-language template")
			}
			for lang, marker := range markers {
				if strings.Contains(html, marker) != (lang == tc.want) {
					panic(name + "/" + tc.name + ": wrong language marker " + lang)
				}
			}
			if strings.Count(html, `href="https://example.com/verify?token=preview&amp;type=signup"`) != 2 {
				panic(name + "/" + tc.name + ": confirmation link was changed or not escaped")
			}
			if *outputDir != "" && tc.name == "native-"+tc.want {
				must(os.WriteFile(filepath.Join(*outputDir, name+"-"+tc.want+".html"), rendered.Bytes(), 0644))
			}
			checks++
		}
	}
	fmt.Printf("%d subject/body rendering cases passed.\n", checks)
}
