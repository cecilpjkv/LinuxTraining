# reference fix (not imported; used by scripts/check_scenarios.py)
cd /srv/site
cat > index.html <<'HTML'
<!doctype html>
<title>Example Corp</title>
<h1>Example Corp</h1>
<p>Release 2.3</p>
<p>We build better things.</p>
<footer>Call us: 555-0199 | (c) 2026 Example Corp</footer>
HTML
git add index.html
git commit -qm "Merge release 2.3 (keep the support phone hotfix)"
git push -q origin main
