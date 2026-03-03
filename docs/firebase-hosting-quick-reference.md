# Firebase Hosting Quick Setup Reference

## Required GitHub Secrets

| Secret Name                | Description                  | Example                                                                 |
| -------------------------- | ---------------------------- | ----------------------------------------------------------------------- |
| `FIREBASE_SERVICE_ACCOUNT` | Service account JSON content | `{"type": "service_account", "project_id": "my-project", "private_key_id": "abc123"...}` |
| `FIREBASE_PROJECT_ID`      | Firebase project ID          | `my-flutter-app-12345`                                                  |

## Firebase Project Setup

1. **Firebase Console** → **Create Project**
2. **Enable Hosting** → **Get started**
3. **Google Cloud Console** → **IAM & Admin** → **Service Accounts**
4. **Create Service Account** with roles:
   - Firebase Admin
   - Firebase Hosting Admin
5. **Create JSON Key** and download

## Getting Service Account JSON Content

```bash
# Method 1: Using cat and pbcopy (macOS)
cat path/to/firebase-service-account.json | pbcopy

# Method 2: Manual copy
# Copy the entire JSON content including all curly braces
```

## Firebase Configuration

```json
// firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [{"key": "Cache-Control", "value": "max-age=31536000"}]
      }
    ]
  }
}
```

## Workflow Configuration

```yaml
- name: Deploy to Firebase Hosting
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: "${{ secrets.GITHUB_TOKEN }}"
    firebaseServiceAccount: "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}"
    channelId: live
    projectId: ${{ secrets.FIREBASE_PROJECT_ID }}
```

## Build Output

- **Web Build**: `build/web/`
- **Firebase Hosting**: Available at your Firebase project URL
- **Deployment Time**: Usually 1-3 minutes

## Common Issues & Solutions

| Issue                      | Solution                                                      |
| -------------------------- | ------------------------------------------------------------- |
| Firebase project not found| Verify project ID and service account access                 |
| Permission denied          | Check service account roles and Firebase Hosting API         |
| Build failed               | Check Flutter web configuration and dependencies             |
| Deployment failed          | Verify firebase.json and Firebase CLI compatibility          |

## Verification Steps

1. ✅ Firebase project created
2. ✅ Firebase Hosting enabled
3. ✅ Service account created with proper roles
4. ✅ Firebase Hosting API enabled
5. ✅ Service account JSON downloaded
6. ✅ Secrets added to GitHub
7. ✅ firebase.json configured

## Performance Optimization

```bash
# Optimized build command
flutter build web --release --tree-shake-icons
```

## Custom Domain Setup

1. **Firebase Console** → **Hosting** → **Add custom domain**
2. **Verify domain ownership**
3. **Configure DNS records**
4. **Wait for SSL certificate**

## Environment-Specific Deployments

```yaml
# Production
if: github.ref == 'refs/heads/main'
channelId: live

# Staging
if: github.ref == 'refs/heads/develop'
channelId: staging
```

## Monitoring

- **Firebase Analytics**: User behavior tracking
- **Firebase Performance**: Performance monitoring
- **Firebase Crashlytics**: Error tracking
- **Hosting Usage**: Bandwidth and requests

---

**Need Help?** Check the full [Firebase Hosting Setup Guide](./firebase-hosting-setup.md) for detailed instructions.
