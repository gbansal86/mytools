# Adding the Binary Assets

The GitHub connector used from ChatGPT can safely write repository text files, but it does not directly stream arbitrary local binary files from the chat render container into GitHub.

The production master video from the reference project was approximately 210 MB, which is also above GitHub's normal 100 MB single-file limit.

## Recommended Git LFS workflow

After downloading the reference assets locally:

```bash
git clone https://github.com/gbansal86/mytools.git
cd mytools
git checkout add-ai-video-production-system

git lfs install
git lfs track "*.mp4"
git lfs track "*.jpg"
git lfs track "*.png"

mkdir -p tools/AI-Video-Production-System/assets

# Copy the reference images into:
# tools/AI-Video-Production-System/assets/

# Copy the full reference video into:
# tools/AI-Video-Production-System/reference_video.mp4

git add .gitattributes tools/AI-Video-Production-System
git commit -m "Add AI video reference images and video"
git push origin add-ai-video-production-system
```

Then merge the existing pull request after CI/status checks pass.

## Why LFS

Git LFS is the correct repository mechanism for large binary media. It avoids GitHub's standard per-file size restriction and keeps the repository clone lightweight.
