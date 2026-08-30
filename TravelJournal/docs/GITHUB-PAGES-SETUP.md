# Enabling GitHub Pages

## One-time setup (do this once after pushing to GitHub)

1. Go to your GitHub repo → **Settings** → **Pages** (left sidebar)
2. Under **Source**, choose **Deploy from a branch**
3. Branch: `main` · Folder: `/docs`
4. Click **Save**

GitHub will publish the site within ~2 minutes. The URLs will be:

| Page | URL |
|------|-----|
| Home | https://gcrook.github.io/traveljournal-ai/ |
| Privacy Policy | https://gcrook.github.io/traveljournal-ai/privacy/ |
| Support | https://gcrook.github.io/traveljournal-ai/support/ |

These match exactly what's in App Store Connect metadata and the privacy policy contact links.

## If you don't have a GitHub repo yet

1. Go to https://github.com/new
2. Name it `traveljournal-ai`
3. Set visibility to **Public** (required for free GitHub Pages)
4. Push your TravelJournal folder to it

```bash
cd /path/to/TravelJournal
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/gcrook/traveljournal-ai.git
git push -u origin main
```
