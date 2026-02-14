# CI/CD Setup Documentation

## Flutter Analyze CI

This repository uses GitHub Actions to automatically analyze Flutter code on every push and pull request.

## Workflow Configuration

**File**: `.github/workflows/flutter-analyze.yml`

### Triggers

The workflow runs on:
- Push to branches: `main`, `master`, `develop`, `copilot/**`
- Pull requests to: `main`, `master`, `develop`

### Steps

1. **Checkout Code**: Uses `actions/checkout@v4`
2. **Set Up Flutter**: Uses `subosito/flutter-action@v2`
   - Version: 3.24.0 (stable)
   - Caching enabled for faster builds
3. **Install Dependencies**: Runs `flutter pub get`
4. **Verify Formatting**: Runs `dart format --output=none --set-exit-if-changed .`
5. **Analyze Code**: Runs `flutter analyze --fatal-infos --fatal-warnings`
6. **Run Tests**: Runs `flutter test` (currently soft-fail with `continue-on-error: true`)

## Local Development Commands

Use the Makefile for convenient local development:

```bash
# Check code quality (strict mode)
make analyze

# Format all Dart code
make fmt

# Run tests
make test

# Clean build artifacts
make clean
```

## Analysis Configuration

The analysis is configured in `analysis_options.yaml`:
- Uses `package:flutter_lints/flutter.yaml`
- Enforces `prefer_single_quotes`
- All warnings treated as errors in CI (`--fatal-warnings`)
- Info messages also treated as errors in CI (`--fatal-infos`)

## CI Requirements

For code to pass CI:
- ✅ All code must be properly formatted
- ✅ No analysis warnings or errors
- ✅ No linting issues
- ✅ Tests must pass (when fully implemented)

## Troubleshooting

### Locally Run CI Checks

Before pushing, run these commands to catch issues early:

```bash
# 1. Format code
make fmt

# 2. Check for analysis issues
make analyze

# 3. Run tests
make test
```

### Common Issues

1. **Formatting Issues**: Run `make fmt` to auto-fix
2. **Analysis Warnings**: Fix warnings shown by `make analyze`
3. **Import Issues**: Ensure all dependencies are in `pubspec.yaml`

## Best Practices

1. **Run `make analyze` before committing**
2. **Use `make fmt` to maintain consistent formatting**
3. **Address all warnings and errors**
4. **Keep `analysis_options.yaml` up to date**
5. **Follow the coding standards in `coding-standards.md`**

## Future Enhancements

Potential additions to the CI workflow:
- Code coverage reporting
- Integration tests
- Build verification for multiple platforms
- Automated deployment
- Performance benchmarks
