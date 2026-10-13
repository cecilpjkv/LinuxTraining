sleep 1
page=$(curl -s -m 5 http://127.0.0.1:8000/)
if printf '%s' "$page" | grep -q 'Release 2.3' && printf '%s' "$page" | grep -q '555-0199' && printf '%s' "$page" | grep -q '(c) 2026' && printf '%s' "$page" | grep -q 'better things' && ! printf '%s' "$page" | grep -q '<<<<<<<'; then
  pass site_content
else
  fail site_content "the homepage does not show release 2.3 with the new phone number"
fi
if grep -rqE '^(<<<<<<<|>>>>>>>|=======$)' /srv/site --include='*.html' --include='*.css' --exclude-dir=.git; then fail no_markers "conflict markers left in /srv/site"; else pass no_markers; fi
cd /srv/site
if [ ! -e .git/MERGE_HEAD ] && [ -z "$(git status --porcelain 2>/dev/null)" ] && git rev-parse -q --verify HEAD >/dev/null; then pass clone_clean; else fail clone_clean "a merge is in progress or the clone has uncommitted changes"; fi
head=$(git rev-parse HEAD 2>/dev/null); central=$(git --git-dir=/srv/git/site.git rev-parse main 2>/dev/null)
if [ -n "$head" ] && [ "$head" = "$central" ] && git --git-dir=/srv/git/site.git merge-base --is-ancestor "$(cat /var/lib/.lt-hotfix)" main 2>/dev/null; then
  pass central_up_to_date
else
  fail central_up_to_date "the central main is not the deployed commit, or lacks the hotfix"
fi
