#!/usr/bin/env bash
set -euo pipefail

# Gera um relatorio HTML simples com informacoes do sistema.
# Uso:
#   bash gerar_relatorio.sh [saida_html]

OUTPUT_FILE="${1:-relatorio.html}"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
HOSTNAME_VALUE="$(hostname 2>/dev/null || echo 'N/A')"
KERNEL_VALUE="$(uname -sr 2>/dev/null || echo 'N/A')"
UPTIME_VALUE="$(uptime 2>/dev/null || echo 'N/A')"
CURRENT_USER="${USER:-${USERNAME:-N/A}}"

cat > "$OUTPUT_FILE" <<EOF
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Relatorio de Sistema</title>
  <style>
    :root {
      --bg: #f4f7fb;
      --card: #ffffff;
      --text: #18212f;
      --muted: #5f6b7a;
      --line: #d6deea;
      --accent: #0f5cc0;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      padding: 32px;
      background: radial-gradient(circle at top right, #e7eefc, var(--bg));
      color: var(--text);
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    }

    .report {
      max-width: 820px;
      margin: 0 auto;
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 14px;
      overflow: hidden;
      box-shadow: 0 10px 25px rgba(20, 35, 60, 0.08);
    }

    .header {
      padding: 24px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(110deg, #f8fbff, #ecf3ff);
    }

    h1 {
      margin: 0 0 6px;
      font-size: 1.45rem;
    }

    .subtitle {
      margin: 0;
      color: var(--muted);
      font-size: 0.95rem;
    }

    .content {
      padding: 22px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
    }

    th, td {
      text-align: left;
      padding: 12px 14px;
      border-bottom: 1px solid var(--line);
      vertical-align: top;
      word-break: break-word;
    }

    th {
      width: 210px;
      background: #f6f9ff;
      color: #1f3d66;
      font-weight: 600;
    }

    tr:last-child th,
    tr:last-child td {
      border-bottom: none;
    }

    .footer {
      padding: 14px 22px 20px;
      color: var(--muted);
      font-size: 0.86rem;
    }

    .tag {
      display: inline-block;
      padding: 2px 10px;
      border-radius: 999px;
      border: 1px solid #c8dcff;
      background: #edf4ff;
      color: var(--accent);
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.03em;
      text-transform: uppercase;
    }
  </style>
</head>
<body>
  <main class="report">
    <header class="header">
      <span class="tag">Automatizado</span>
      <h1>Relatorio de Sistema</h1>
      <p class="subtitle">Gerado em: $GENERATED_AT</p>
    </header>

    <section class="content">
      <table>
        <tbody>
          <tr>
            <th>Usuario</th>
            <td>$CURRENT_USER</td>
          </tr>
          <tr>
            <th>Host</th>
            <td>$HOSTNAME_VALUE</td>
          </tr>
          <tr>
            <th>Kernel</th>
            <td>$KERNEL_VALUE</td>
          </tr>
          <tr>
            <th>Uptime</th>
            <td>$UPTIME_VALUE</td>
          </tr>
          <tr>
            <th>Diretorio de execucao</th>
            <td>$(pwd)</td>
          </tr>
        </tbody>
      </table>
    </section>

    <footer class="footer">
      Este arquivo foi gerado por <code>gerar_relatorio.sh</code>.
    </footer>
  </main>
</body>
</html>
EOF

echo "Relatorio gerado com sucesso: $OUTPUT_FILE"
