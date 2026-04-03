# Prelude legal site (static)

Privacy and support pages for App Store Connect and users, styled to match the Prelude design system.

## URLs (after DNS + Vercel)

| Page    | Path |
| ------- | ---- |
| Home (hub) | `https://legal.echovault.me/` |
| Privacy | `https://legal.echovault.me/preludeprivacy` |
| Support | `https://legal.echovault.me/preludesupport` |

There is no `/vercel` route — that URL will 404. Use the paths above or your Vercel dashboard URL for project settings.

## Local preview

From this directory:

```bash
npx --yes serve .
```

Open `/preludeprivacy` and `/preludesupport` (or open `preludeprivacy/index.html` directly; nav links use absolute paths `/preludeprivacy` which work on Vercel).

## Deploy with Vercel CLI

1. [Install Vercel CLI](https://vercel.com/docs/cli) and run `vercel login`.
2. From **`web/legal-site/`** (the folder that contains `preludeprivacy/`, `preludesupport/`, and `vercel.json`):

   ```bash
   cd web/legal-site
   vercel        # preview
   vercel --prod # production
   ```

3. **First-time prompts:** If Vercel asks **“In which directory is your code located?”**, enter **`.`** (dot only). You are already inside the project root; do **not** enter `./legal-site` or you will get an error about `.../legal-site/legal-site` not existing.

4. In the [Vercel dashboard](https://vercel.com/dashboard), create or select a **new** project for this folder (do not link to the hackathon `prelude.echovault.me` project unless you intend to replace that deployment).
5. Add domain **`legal.echovault.me`**: Project → Settings → Domains. Configure DNS at your provider (CNAME to `cname.vercel-dns.com` or the records Vercel shows).

## App Store Connect

Paste the two HTTPS URLs above into the app’s **Privacy Policy URL** and **Support URL** fields. Ensure **App Privacy** answers match the published privacy policy.
