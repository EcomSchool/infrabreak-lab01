from flask import Flask, request, render_template_string, session, jsonify, redirect, url_for
import hashlib
import os

app = Flask(__name__, static_folder='static')
# A simple secret key for CTF session tracking capability
app.secret_key = "ecom_cyber_lab_01_secret"

# Flags stored as SHA256 hashes
FLAGS = {
    "1": {
        "name": "Stage 1 — FTP Anonymous Access",
        "hint": "You found something in the FTP server's public directory",
        "hash": hashlib.sha256(b"ECOM{anon_ftp_is_a_bad_idea}").hexdigest()
    },
    "2": {
        "name": "Stage 2 — Encrypted Archive",
        "hint": "Crack the extracted zip using rockyou (fast!)",
        "hash": hashlib.sha256(b"ECOM{zip_crack3d_w1th_r0cky0u}").hexdigest()
    },
    "3": {
        "name": "Stage 3 — Database Dump",
        "hint": "Check all tables inside the internaldb",
        "hash": hashlib.sha256(b"ECOM{db_dump_succ3ssful_g00d_j0b}").hexdigest()
    },
    "4": {
        "name": "Stage 4 — SSH Access",
        "hint": "Look for leftover private keys in the database notes",
        "hash": hashlib.sha256(b"ECOM{ssh_k3y_fr0m_db_n1c3_w0rk}").hexdigest()
    },
    "5": {
        "name": "Stage 5 — Remote Code Execution",
        "hint": "Metasploit has a module for Postgres COPY TO/FROM RCE",
        "hash": hashlib.sha256(b"ECOM{rce_v1a_cve_2019_9193_pwned}").hexdigest()
    },
    "6": {
        "name": "Stage 6 — Root",
        "hint": "Check sudo privileges for the postgres user",
        "hash": hashlib.sha256(b"ECOM{r00t_0wn3d_infrabreak_01_gg}").hexdigest()
    },
}

HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>InfraBreak: Lab 01 — Flag Checker</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&family=Fira+Code:wght@400;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<style>
  :root {
    --bg-dark: #050505;
    --bg-panel: rgba(20, 22, 28, 0.65);
    --neon-green: #00ff88;
    --neon-blue: #00aaff;
    --neon-red: #ff3366;
    --text-main: #f0f4f8;
    --text-muted: #8b949e;
    --border-color: rgba(255, 255, 255, 0.08);
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }
  
  body {
    background-color: var(--bg-dark);
    background-image: 
      radial-gradient(circle at 15% 50%, rgba(0, 255, 136, 0.03), transparent 25%),
      radial-gradient(circle at 85% 30%, rgba(0, 170, 255, 0.03), transparent 25%);
    background-attachment: fixed;
    color: var(--text-main);
    font-family: 'Outfit', sans-serif;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 2rem;
  }

  .container {
    display: grid;
    grid-template-columns: 320px 1fr;
    gap: 2rem;
    max-width: 1200px;
    width: 100%;
    align-items: start;
  }

  @media (max-width: 900px) {
    .container { grid-template-columns: 1fr; }
  }

  /* Glassmorphism Panel Base */
  .panel {
    background: var(--bg-panel);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border: 1px solid var(--border-color);
    border-radius: 16px;
    padding: 1.5rem;
    box-shadow: 0 8px 32px rgba(0,0,0,0.3);
  }

  /* Sidebar - Scoreboard */
  .sidebar {
    position: sticky;
    top: 2rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  
  .logo-container {
    text-align: center;
    margin-bottom: 1rem;
  }
  
  .logo-container img {
    width: 140px;
    margin-bottom: 1rem;
    filter: drop-shadow(0 0 15px rgba(0, 255, 136, 0.2));
  }
  
  .logo-container h1 {
    font-size: 1.5rem;
    font-weight: 700;
    letter-spacing: 1px;
    background: linear-gradient(90deg, var(--neon-blue), var(--neon-green));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  
  .score-card {
    text-align: center;
    padding: 1.5rem;
    border-radius: 12px;
    background: rgba(0,0,0,0.4);
    border: 1px solid rgba(0, 255, 136, 0.15);
    position: relative;
    overflow: hidden;
  }
  
  .score-card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; height: 2px;
    background: linear-gradient(90deg, transparent, var(--neon-green), transparent);
  }
  
  .score-value {
    font-family: 'Fira Code', monospace;
    font-size: 2.8rem;
    font-weight: 600;
    color: var(--neon-green);
    text-shadow: 0 0 20px rgba(0, 255, 136, 0.4);
    line-height: 1.1;
  }
  
  .score-label {
    text-transform: uppercase;
    font-size: 0.75rem;
    letter-spacing: 2px;
    color: var(--text-muted);
    margin-bottom: 0.5rem;
  }

  .progress-wrapper {
    margin-top: 1rem;
  }
  
  .progress-bar {
    height: 6px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    overflow: hidden;
    margin-top: 0.5rem;
  }
  
  .progress-fill {
    height: 100%;
    background: linear-gradient(90deg, var(--neon-blue), var(--neon-green));
    box-shadow: 0 0 10px var(--neon-green);
    transition: width 0.8s ease-out;
  }

  .stats-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.85rem;
    color: var(--text-muted);
    margin-top: 0.5rem;
  }

  .btn-reset {
    width: 100%;
    background: rgba(255, 51, 102, 0.1);
    color: var(--neon-red);
    border: 1px solid rgba(255, 51, 102, 0.3);
    padding: 0.75rem;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.3s ease;
    font-family: 'Outfit', sans-serif;
  }
  
  .btn-reset:hover {
    background: var(--neon-red);
    color: #fff;
    box-shadow: 0 0 15px rgba(255, 51, 102, 0.4);
  }

  /* Main Stages Section */
  .stages-container {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .stage {
    position: relative;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  
  .stage:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 40px rgba(0,0,0,0.4);
  }
  
  .stage.solved {
    border-color: rgba(0, 255, 136, 0.3);
    background: linear-gradient(145deg, rgba(20, 22, 28, 0.8), rgba(0, 30, 15, 0.3));
  }

  .stage-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .stage-title {
    font-size: 1.2rem;
    font-weight: 600;
    color: #fff;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .badge-solved {
    background: rgba(0, 255, 136, 0.1);
    color: var(--neon-green);
    border: 1px solid var(--neon-green);
    padding: 0.2rem 0.6rem;
    border-radius: 20px;
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 1px;
    box-shadow: 0 0 10px rgba(0, 255, 136, 0.2);
  }

  .stage-stats {
    font-size: 0.8rem;
    color: var(--text-muted);
    background: rgba(0,0,0,0.3);
    padding: 0.2rem 0.6rem;
    border-radius: 4px;
  }

  /* Hint System */
  .hint-section {
    margin-bottom: 1.5rem;
  }
  
  .hint-box {
    background: rgba(0, 170, 255, 0.05);
    border-left: 3px solid var(--neon-blue);
    padding: 1rem;
    border-radius: 0 8px 8px 0;
    color: #c0d0e0;
    font-size: 0.9rem;
  }

  .btn-hint {
    background: transparent;
    color: var(--neon-blue);
    border: 1px dashed var(--neon-blue);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.8rem;
    transition: all 0.3s;
  }
  
  .btn-hint:hover {
    background: rgba(0, 170, 255, 0.1);
    box-shadow: 0 0 10px rgba(0, 170, 255, 0.2);
  }

  /* Form and Inputs */
  .flag-form {
    display: flex;
    gap: 0.5rem;
  }

  .flag-input {
    flex: 1;
    background: rgba(0,0,0,0.5);
    border: 1px solid var(--border-color);
    color: var(--neon-green);
    padding: 0.8rem 1rem;
    border-radius: 8px;
    font-family: 'Fira Code', monospace;
    font-size: 0.95rem;
    transition: all 0.3s;
  }

  .flag-input:focus {
    outline: none;
    border-color: var(--neon-green);
    box-shadow: 0 0 15px rgba(0, 255, 136, 0.15);
  }

  .btn-submit {
    background: var(--neon-green);
    color: #000;
    border: none;
    padding: 0 1.5rem;
    border-radius: 8px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s;
  }

  .btn-submit:hover {
    background: #00cc6a;
    box-shadow: 0 0 15px rgba(0, 255, 136, 0.4);
    transform: translateX(2px);
  }

  .btn-submit:disabled {
    background: #333;
    color: #666;
    cursor: not-allowed;
    box-shadow: none;
  }

  /* Feedback Alerts */
  .alert {
    margin-top: 1rem;
    padding: 0.75rem 1rem;
    border-radius: 8px;
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    animation: fadeIn 0.3s ease-out forwards;
  }

  .alert-success {
    background: rgba(0, 255, 136, 0.1);
    border: 1px solid var(--neon-green);
    color: var(--neon-green);
  }

  .alert-error {
    background: rgba(255, 51, 102, 0.1);
    border: 1px solid var(--neon-red);
    color: var(--neon-red);
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(-5px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .footer {
    text-align: center;
    margin-top: 3rem;
    color: var(--text-muted);
    font-size: 0.8rem;
    letter-spacing: 1px;
  }
</style>
</head>
<body>

<div class="container">
  
  <!-- Sidebar -->
  <div class="sidebar">
    <div class="panel logo-container">
      <img src="{{ url_for('static', filename='logo.png') }}" alt="EcomSchool Logo">
      <h1>EcomSchool</h1>
      <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.5rem;">InfraBreak Lab 01</p>
    </div>

    <div class="panel score-card">
      <div class="score-label">Global Score</div>
      <div class="score-value">{{ score }}</div>
      
      <div class="progress-wrapper">
        <div class="stats-row">
          <span>Progress</span>
          <span>{{ progress }}%</span>
        </div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: {{ progress }}%;"></div>
        </div>
        <div class="stats-row" style="margin-top: 0.8rem;">
          <span>Flags Captured</span>
          <span style="color: #fff;">{{ solved_count }} / {{ total_flags }}</span>
        </div>
      </div>
    </div>

    </div>
  </div>

  <!-- Main Stages -->
  <div class="stages-container">
    {% for sid, stage in stages.items() %}
    <div class="panel stage {% if stage.solved %}solved{% endif %}">
      
      <div class="stage-header">
        <div class="stage-title">
          <i class="fa-solid fa-flag {% if stage.solved %}fa-flip{% endif %}" style="color: {% if stage.solved %}var(--neon-green){% else %}var(--text-muted){% endif %}"></i>
          {{ stage.name }}
          {% if stage.solved %}
            <span class="badge-solved"><i class="fa-solid fa-check"></i> SOLVED</span>
          {% endif %}
        </div>
        
        {% if stage.solved %}
          <div class="stage-stats" style="color: var(--neon-green); border: 1px solid rgba(0,255,136,0.3);">
             +{{ stage.points_earned }} pts
          </div>
        {% else %}
          <div class="stage-stats">
            Attempts: <span style="color: {% if stage.attempts > 0 %}var(--neon-red){% else %}inherit{% endif %}">{{ stage.attempts }}</span>
          </div>
        {% endif %}
      </div>

      <!-- Hint System -->
      <div class="hint-section">
        {% if stage.hints_revealed or stage.solved %}
          {% if stage.hint %}
            <div class="hint-box">
              <i class="fa-solid fa-lightbulb" style="color: var(--neon-blue); margin-right: 0.5rem;"></i>
              {{ stage.hint }}
            </div>
          {% endif %}
        {% else %}
          <form method="POST" action="/hint">
            <input type="hidden" name="stage_id" value="{{ sid }}">
            <button type="submit" class="btn-hint" onclick="return confirm('Reveal hint? This will cost 200 points from this flag.')">
              <i class="fa-solid fa-unlock-keyhole"></i> Reveal Hint (-200 pts)
            </button>
          </form>
        {% endif %}
      </div>

      <!-- Form -->
      <form method="POST" action="/check" class="flag-form">
        <input type="hidden" name="stage_id" value="{{ sid }}">
        <input type="text" name="flag" class="flag-input" placeholder="ECOM{...}" 
               autocomplete="off" spellcheck="false" 
               {% if stage.solved %}value="********************************" disabled{% endif %} required>
        <button type="submit" class="btn-submit" {% if stage.solved %}disabled{% endif %}>
          <i class="fa-solid fa-paper-plane"></i>
        </button>
      </form>

      <!-- Feedback -->
      {% if result and result.stage == sid %}
        {% if result.correct %}
          <div class="alert alert-success">
            <i class="fa-solid fa-circle-check"></i> Flag accepted! Great job.
          </div>
        {% else %}
          <div class="alert alert-error">
            <i class="fa-solid fa-circle-xmark"></i> Incorrect flag. Look closer.
          </div>
        {% endif %}
      {% endif %}

    </div>
    {% endfor %}
    
    <div class="footer">InfraBreak Lab 01 &copy; EcomSchool Cybersecurity</div>
  </div>

</div>

</body>
</html>
"""

def initialize_session():
    if "solved" not in session: session["solved"] = []
    if "attempts" not in session: session["attempts"] = {}
    if "hints" not in session: session["hints"] = {}

def compute_state():
    initialize_session()
    score = 0
    solved_count = len(session["solved"])
    total_flags = len(FLAGS)
    
    stages_data = {}
    for sid, flag in FLAGS.items():
        is_solved = sid in session["solved"]
        hints = session.get("hints", {}).get(sid, False)
        attempts = session.get("attempts", {}).get(sid, 0)
        
        points_earned = 0
        if is_solved:
            points_earned += 1000
        if hints: 
            points_earned -= 200
        points_earned -= (attempts * 50)
        
        score += points_earned
            
        stages_data[sid] = {
            "name": flag["name"],
            "hint": flag["hint"],
            "solved": is_solved,
            "attempts": attempts,
            "hints_revealed": hints,
            "points_earned": points_earned
        }
        
    progress = int((solved_count / total_flags) * 100) if total_flags > 0 else 0
    max_score = total_flags * 1000
    
    return stages_data, progress, score, max_score, solved_count, total_flags

@app.route("/", methods=["GET"])
def index():
    stages_data, progress, score, max_score, solved_count, total_flags = compute_state()
    return render_template_string(HTML, 
                                  stages=stages_data, 
                                  progress=progress, 
                                  score=score,
                                  max_score=max_score,
                                  solved_count=solved_count,
                                  total_flags=total_flags,
                                  result=None)

@app.route("/check", methods=["POST"])
def check():
    initialize_session()
    stage_id = request.form.get("stage_id", "")
    flag_input = request.form.get("flag", "").strip()
    result = {"stage": stage_id, "correct": False}

    if stage_id in FLAGS and stage_id not in session["solved"]:
        submitted_hash = hashlib.sha256(flag_input.encode()).hexdigest()
        if submitted_hash == FLAGS[stage_id]["hash"]:
            result["correct"] = True
            solved_list = session["solved"]
            solved_list.append(stage_id)
            session["solved"] = solved_list
        else:
            attempts = session.get("attempts", {})
            attempts[stage_id] = attempts.get(stage_id, 0) + 1
            session["attempts"] = attempts

    session.modified = True
    stages_data, progress, score, max_score, solved_count, total_flags = compute_state()
    return render_template_string(HTML, 
                                  stages=stages_data, 
                                  progress=progress, 
                                  score=score,
                                  max_score=max_score,
                                  solved_count=solved_count,
                                  total_flags=total_flags,
                                  result=result)

@app.route("/hint", methods=["POST"])
def reveal_hint():
    initialize_session()
    stage_id = request.form.get("stage_id", "")
    if stage_id in FLAGS and stage_id not in session["solved"]:
        hints = session.get("hints", {})
        hints[stage_id] = True
        session["hints"] = hints
        session.modified = True
        
    return redirect(url_for('index'))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8088)
