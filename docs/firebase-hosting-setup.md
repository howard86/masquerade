# Firebase Hosting Setup Guide

This guide explains how to set up automated Firebase Hosting deployment for your Flutter web app using GitHub Actions.

## Prerequisites

- Google account
- Firebase project
- GitHub repository with Actions enabled
- Flutter web app configured

## Step 1: Create Firebase Project

1. **Go to Firebase Console**
   - Navigate to [Firebase Console](https://console.firebase.google.com/)
   - Sign in with your Google account

2. **Create New Project**
   - Click "Create a project"
   - Enter project name (e.g., "my-flutter-app")
   - Choose whether to enable Google Analytics
   - Click "Create project"

3. **Configure Project Settings**
   - Note the Project ID (you'll need this later)
   - Go to Project Settings → General tab
   - Copy the Project ID

## Step 2: Enable Firebase Hosting

1. **Go to Hosting Section**
   - In Firebase Console, click "Hosting" in the left sidebar
   - Click "Get started"

2. **Initialize Hosting**
   - Choose "Web app" as the platform
   - Register your app with a nickname
   - Click "Register app"

3. **Configure Hosting**
   - Choose your hosting plan (Spark plan is free)
   - Set up custom domain (optional)
   - Configure SSL certificate (automatic)

## Step 3: Create Service Account

1. **Go to Google Cloud Console**
   - Navigate to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your Firebase project

2. **Enable Required APIs**
   - Go to "APIs & Services" → "Library"
   - Enable "Firebase Hosting API"
   - Enable "Firebase Management API"

3. **Create Service Account**
   - Go to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Enter name: "GitHub Actions Firebase"
   - Add description: "Service account for automated Firebase deployments"
   - Click "Create and Continue"

4. **Assign Roles**
   - Add role: "Firebase Admin"
   - Add role: "Firebase Hosting Admin"
   - Click "Continue" and then "Done"

5. **Create and Download Key**
   - Click on the created service account
   - Go to "Keys" tab
   - Click "Add Key" → "Create new key"
   - Choose "JSON" format
   - Click "Create" (this downloads the JSON file)

## Step 4: Configure GitHub Secrets

Add the required secrets to your GitHub repository:

1. **Go to Repository Settings**
   - Navigate to your GitHub repository
   - Click on "Settings" tab
   - Go to "Secrets and variables" → "Actions"

2. **Add Required Secrets**

   | Secret Name                | Description                    | Value                                    |
   | -------------------------- | ------------------------------ | ---------------------------------------- |
   | `FIREBASE_SERVICE_ACCOUNT` | Service account JSON content   | Copy the entire content of the JSON file |
   | `FIREBASE_PROJECT_ID`      | Firebase project ID            | The Firebase project ID from console     |

### How to Get the Service Account JSON Content

```bash
# Method 1: Using cat and pbcopy (macOS)
cat path/to/firebase-service-account.json | pbcopy

# Method 2: Manual copy
# Copy the entire JSON content including all curly braces
```

## Step 5: Configure Firebase Hosting

1. **Initialize Firebase in Project**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools

   # Login to Firebase
   firebase login

   # Initialize Firebase in your project
   firebase init hosting
   ```

2. **Configure firebase.json**
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ],
       "headers": [
         {
           "source": "**/*.@(js|css)",
           "headers": [
             {
               "key": "Cache-Control",
               "value": "max-age=31536000"
             }
           ]
         }
       ]
     }
   }
   ```

## Step 6: Test the Deployment

1. **Push to Main Branch**
   - The CI/CD pipeline will automatically trigger on pushes to `main`
   - Monitor the Actions tab in your GitHub repository

2. **Check Firebase Hosting**
   - Go to Firebase Console → Hosting
   - Your deployment should appear in the hosting dashboard
   - Click on the hosting URL to view your deployed app

## Step 7: Configure Custom Domain (Optional)

1. **Add Custom Domain**
   - Go to Firebase Console → Hosting
   - Click "Add custom domain"
   - Enter your domain name
   - Follow the verification steps

2. **Configure DNS**
   - Add the required DNS records
   - Wait for SSL certificate provisioning
   - Test the custom domain

## Troubleshooting

### Common Issues

1. **"Firebase project not found" Error**
   - Verify the Firebase project ID is correct
   - Check that the project exists in Firebase Console
   - Ensure the service account has access to the project

2. **"Permission denied" Error**
   - Verify the service account has proper roles
   - Check that Firebase Hosting API is enabled
   - Ensure the service account JSON is correct

3. **"Build failed" Error**
   - Check Flutter web build configuration
   - Verify all dependencies are installed
   - Review the build logs for specific errors

4. **"Deployment failed" Error**
   - Check Firebase CLI version compatibility
   - Verify firebase.json configuration
   - Check hosting rules and redirects

### Debug Steps

1. **Check GitHub Actions Logs**
   - Go to Actions tab in your repository
   - Click on the failed workflow run
   - Expand the "Deploy to Firebase Hosting" step

2. **Test Locally**
   - Build the web app locally:
   ```bash
   flutter build web --release
   ```
   - Test Firebase deployment locally:
   ```bash
   firebase deploy --only hosting
   ```

3. **Verify Firebase Configuration**
   - Check firebase.json syntax
   - Verify hosting rules
   - Test Firebase CLI authentication

## Security Best Practices

1. **Limit Service Account Permissions**
   - Use the minimum required roles
   - Regularly review and rotate service account keys

2. **Secure Secret Storage**
   - Never commit service account keys to your repository
   - Use GitHub Secrets for all sensitive data

3. **Monitor Usage**
   - Regularly check Firebase Console for usage
   - Monitor GitHub Actions logs for suspicious activity

## Performance Optimization

### Build Optimization

1. **Enable Tree Shaking**
   ```bash
   flutter build web --release --tree-shake-icons
   ```

2. **Optimize Assets**
   - Compress images
   - Use appropriate image formats
   - Minimize asset sizes

3. **Code Splitting**
   - Use lazy loading for routes
   - Implement dynamic imports
   - Optimize bundle size

### Hosting Optimization

1. **Caching Headers**
   ```json
   {
     "headers": [
       {
         "source": "**/*.@(js|css)",
         "headers": [
           {
             "key": "Cache-Control",
             "value": "max-age=31536000"
           }
         ]
       }
     ]
   }
   ```

2. **Compression**
   - Enable gzip compression
   - Use Brotli compression
   - Optimize file sizes

3. **CDN Configuration**
   - Use Firebase Hosting's global CDN
   - Configure edge caching
   - Optimize delivery

## Additional Configuration

### Environment-Specific Deployments

```yaml
# Deploy to production on main branch
if: github.ref == 'refs/heads/main'
channelId: live

# Deploy to preview on develop branch
if: github.ref == 'refs/heads/develop'
channelId: preview
```

### Custom Build Commands

```yaml
- name: Build web with custom flags
  run: |
    flutter build web --release \
      --tree-shake-icons \
      --dart-define=ENVIRONMENT=production \
      --dart-define=API_URL=https://api.example.com
```

### Multiple Environment Support

```yaml
# Production deployment
- name: Deploy to Production
  if: github.ref == 'refs/heads/main'
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    channelId: live
    projectId: ${{ secrets.FIREBASE_PROJECT_ID }}

# Staging deployment
- name: Deploy to Staging
  if: github.ref == 'refs/heads/develop'
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    channelId: staging
    projectId: ${{ secrets.FIREBASE_PROJECT_ID }}
```

## Monitoring and Analytics

### Firebase Analytics
- Enable Firebase Analytics
- Track user behavior
- Monitor performance metrics
- Set up custom events

### Error Monitoring
- Firebase Crashlytics for web
- Custom error tracking
- Performance monitoring
- User feedback collection

## Support

For issues with Firebase Hosting, check:
- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [Firebase CLI Documentation](https://firebase.google.com/docs/cli)
- [Flutter Web Deployment Guide](https://docs.flutter.dev/deployment/web)

## Related Documentation

- [Flutter Deployment Rules](../FLUTTER_RULES_TESTING_GUIDE.md)
- [CI/CD Pipeline Configuration](../.github/workflows/ci_cd.yml)
- [Deployment Overview](./deployment-overview.md)
- [TestFlight Setup Guide](./testflight-setup.md)
- [Google Play Store Setup Guide](./google-play-setup.md)
