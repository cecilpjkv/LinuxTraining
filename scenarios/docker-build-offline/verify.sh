sleep 1
if docker image inspect docs:1.0 >/dev/null 2>&1 && docker run --rm docs:1.0 cat /usr/share/nginx/html/index.html 2>/dev/null | grep -q 'Example API Docs'; then
  pass image_built
else
  fail image_built "docs:1.0 does not exist or does not contain the site"
fi
if curl -s -m 5 http://127.0.0.1:8082/v2/ | grep -q 'API v2 reference'; then pass site_served; else fail site_served "http://localhost:8082/v2/ does not show the docs"; fi
img=$(docker inspect docs --format '{{.Config.Image}}' 2>/dev/null)
mounts=$(docker inspect docs --format '{{len .Mounts}}' 2>/dev/null)
if [ "$(docker inspect docs --format '{{.State.Running}}' 2>/dev/null)" = true ] && printf '%s' "$img" | grep -q 'docs:1.0' && [ "$mounts" = 0 ]; then
  pass container_from_image
else
  fail container_from_image "container docs: image ${img:-none}, mounts ${mounts:-?}"
fi
