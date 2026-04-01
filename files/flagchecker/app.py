from flask import Flask, request, render_template_string
import hashlib

app = Flask(__name__)

# Flags stored as SHA256 hashes so they're not exposed in source
FLAGS = {
    "1": {
        "name": "Stage 1 — FTP Anonymous Access",
        "hint": "You found something in the FTP server's public directory",
        "hash": hashlib.sha256(b"ECOM{anon_ftp_is_a_bad_idea}").hexdigest()
    },
    "2": {
        "name": "Stage 2 — Encrypted Archive",
        "hint": "You cracked the zip and found a flag inside",
        "hash": hashlib.sha256(b"ECOM{zip_crack3d_w1th_r0cky0u}").hexdigest()
    },
    "3": {
        "name": "Stage 3 — Database Dump",
        "hint": "You connected to the database and found something extra",
        "hash": hashlib.sha256(b"ECOM{db_dump_succ3ssful_g00d_j0b}").hexdigest()
    },
    "4": {
        "name": "Stage 4 — SSH Access",
        "hint": "You logged in as charlie and read his home directory",
        "hash": hashlib.sha256(b"ECOM{ssh_k3y_fr0m_db_n1c3_w0rk}").hexdigest()
    },
    "5": {
        "name": "Stage 5 — Remote Code Execution",
        "hint": "You exploited the service and got a shell",
        "hash": hashlib.sha256(b"ECOM{rce_v1a_cve_2019_9193_pwned}").hexdigest()
    },
    "6": {
        "name": "Stage 6 — Root",
        "hint": "You escalated privileges and owned the box",
        "hash": hashlib.sha256(b"ECOM{r00t_0wn3d_infrabreak_01_gg}").hexdigest()
    },
}

HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>InfraBreak: Lab 01 — Flag Checker</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #0a0a0a;
    color: #e0e0e0;
    font-family: 'Courier New', monospace;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 40px 20px;
  }
  .header {
    text-align: center;
    margin-bottom: 40px;
  }
  .header h1 {
    font-size: 2rem;
    color: #00ff88;
    letter-spacing: 2px;
  }
  .header p {
    color: #888;
    margin-top: 8px;
    font-size: 0.9rem;
  }
  .stages {
    width: 100%;
    max-width: 700px;
  }
  .stage {
    background: #111;
    border: 1px solid #222;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 16px;
  }
  .stage h3 {
    color: #00aaff;
    margin-bottom: 6px;
    font-size: 1rem;
  }
  .stage .hint {
    color: #666;
    font-size: 0.8rem;
    margin-bottom: 12px;
  }
  .stage form {
    display: flex;
    gap: 10px;
  }
  .stage input[type=text] {
    flex: 1;
    background: #1a1a1a;
    border: 1px solid #333;
    border-radius: 4px;
    color: #e0e0e0;
    padding: 8px 12px;
    font-family: 'Courier New', monospace;
    font-size: 0.9rem;
  }
  .stage input[type=text]:focus {
    outline: none;
    border-color: #00aaff;
  }
  .stage button {
    background: #00aaff;
    border: none;
    border-radius: 4px;
    color: #000;
    cursor: pointer;
    font-family: 'Courier New', monospace;
    font-size: 0.9rem;
    font-weight: bold;
    padding: 8px 18px;
    transition: background 0.2s;
  }
  .stage button:hover { background: #0088dd; }
  .result-correct {
    margin-top: 10px;
    background: #003322;
    border: 1px solid #00ff88;
    border-radius: 4px;
    color: #00ff88;
    padding: 8px 12px;
    font-size: 0.9rem;
  }
  .result-wrong {
    margin-top: 10px;
    background: #220000;
    border: 1px solid #ff4444;
    border-radius: 4px;
    color: #ff4444;
    padding: 8px 12px;
    font-size: 0.9rem;
  }
  .badge-solved {
    display: inline-block;
    background: #003322;
    border: 1px solid #00ff88;
    border-radius: 12px;
    color: #00ff88;
    font-size: 0.75rem;
    margin-left: 10px;
    padding: 2px 10px;
  }
  .footer {
    margin-top: 40px;
    color: #444;
    font-size: 0.75rem;
    text-align: center;
  }
</style>
</head>
<body>

<div class="header">
  <h1>🔓 InfraBreak: Exploitation Lab 01</h1>
  <p>Submit each flag as you capture it. Flags are in the format <code>ECOM{...}</code></p>
</div>

<div class="stages">
  {% for sid, stage in stages.items() %}
  <div class="stage">
    <h3>{{ stage.name }}
      {% if solved.get(sid) %}<span class="badge-solved">✓ SOLVED</span>{% endif %}
    </h3>
    <div class="hint">{{ stage.hint }}</div>
    <form method="POST" action="/check">
      <input type="hidden" name="stage_id" value="{{ sid }}">
      <input type="text" name="flag" placeholder="ECOM{...}" autocomplete="off" spellcheck="false">
      <button type="submit">Submit</button>
    </form>
    {% if result and result.stage == sid %}
      {% if result.correct %}
        <div class="result-correct">✓ Correct! Flag accepted.</div>
      {% else %}
        <div class="result-wrong">✗ Wrong flag. Keep trying.</div>
      {% endif %}
    {% endif %}
  </div>
  {% endfor %}
</div>

<div class="footer">InfraBreak Lab 01 · ECOM Offensive Cybersecurity Course</div>

</body>
</html>
"""

@app.route("/", methods=["GET"])
def index():
    return render_template_string(HTML, stages=FLAGS, solved={}, result=None)

@app.route("/check", methods=["POST"])
def check():
    stage_id = request.form.get("stage_id", "")
    flag = request.form.get("flag", "").strip()
    result = {"stage": stage_id, "correct": False}

    if stage_id in FLAGS:
        submitted_hash = hashlib.sha256(flag.encode()).hexdigest()
        if submitted_hash == FLAGS[stage_id]["hash"]:
            result["correct"] = True

    solved = {}
    return render_template_string(HTML, stages=FLAGS, solved=solved, result=result)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8088)
