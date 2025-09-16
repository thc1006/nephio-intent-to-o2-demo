# Contributing to Nephio Intent Operator

Thank you for your interest in contributing to the Nephio Intent Operator! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by the [CNCF Code of Conduct](https://github.com/cncf/foundation/blob/main/code-of-conduct.md).

## Getting Started

### Prerequisites

- Go 1.22 or later
- Kubebuilder v4.8+
- Docker (for building images)
- Kubernetes cluster (for testing)
- Make

### Development Setup

1. **Fork and Clone**
   ```bash
   # Fork the repository on GitHub
   git clone https://github.com/YOUR_USERNAME/nephio-intent-operator.git
   cd nephio-intent-operator
   ```

2. **Install Dependencies**
   ```bash
   make setup
   go mod download
   ```

3. **Run Tests**
   ```bash
   make test
   ```

## Development Process

### Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Add or update tests
4. Ensure all tests pass
5. Update documentation
6. Submit a pull request

### Branch Naming

- `feat/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `test/` - Test improvements
- `refactor/` - Code refactoring

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or fixes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Maintenance tasks

Example:
```
feat(controller): add retry logic for intent reconciliation

Implements exponential backoff for failed reconciliation attempts.
This improves reliability when dealing with transient failures.

Fixes #123
```

## Making Changes

### API Changes

1. Modify the types in `api/v1alpha1/`
2. Run code generation:
   ```bash
   make generate
   make manifests
   ```
3. Update API documentation
4. Add conversion webhooks if needed

### Controller Changes

1. Modify controller logic in `controllers/`
2. Update unit tests
3. Add integration tests if needed
4. Test locally:
   ```bash
   make run
   ```

### Testing

#### Unit Tests
```bash
make test
```

#### Integration Tests
```bash
make test-integration
```

#### E2E Tests
```bash
make test-e2e
```

#### Test Coverage
```bash
make test-coverage
```

### Documentation

- Update relevant `.md` files
- Add godoc comments to exported functions
- Update examples in `config/samples/`

## Submitting Changes

### Pull Request Process

1. **Before Submitting**
   - Ensure all tests pass
   - Run linters: `make lint`
   - Update documentation
   - Sign your commits (DCO)

2. **PR Description**
   - Describe what changes you've made
   - Link related issues
   - Include testing steps
   - Add screenshots if relevant

3. **PR Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed

   ## Checklist
   - [ ] My code follows the project style
   - [ ] I've updated documentation
   - [ ] I've added tests
   - [ ] All tests pass
   - [ ] I've signed my commits

   Fixes #(issue)
   ```

4. **Review Process**
   - At least one maintainer approval required
   - CI checks must pass
   - Address review feedback promptly

### Sign Your Work

We use the Developer Certificate of Origin (DCO). Sign your commits:

```bash
git commit -s -m "Your commit message"
```

## Code Style

### Go Code

- Follow [Effective Go](https://golang.org/doc/effective_go.html)
- Use `gofmt` and `golangci-lint`
- Keep functions small and focused
- Write descriptive variable names
- Add comments for exported functions

### YAML Files

- Use 2 spaces for indentation
- Keep lines under 80 characters when possible
- Add comments for non-obvious configurations

## Project Structure

```
operator/
├── api/v1alpha1/        # API definitions
├── controllers/         # Reconciliation logic
├── config/             # Kustomize configurations
├── docs/               # Documentation
├── hack/               # Build scripts
└── test/               # Test suites
```

## Building and Testing

### Build Operator
```bash
make build
```

### Build Docker Image
```bash
make docker-build IMG=nephio-intent-operator:dev
```

### Deploy to Cluster
```bash
make deploy IMG=nephio-intent-operator:dev
```

### Run Locally
```bash
make install  # Install CRDs
make run      # Run operator locally
```

## Release Process

1. Ensure all tests pass on `main`
2. Update version in relevant files
3. Create release notes
4. Tag the release: `git tag -a v0.x.y -m "Release v0.x.y"`
5. Push tag: `git push origin v0.x.y`
6. CI will build and publish release artifacts

## Getting Help

- Open an issue for bugs or feature requests
- Join the discussion in issues
- Check existing issues before creating new ones
- Provide detailed information for bug reports

## Recognition

Contributors are recognized in:
- The CONTRIBUTORS file
- Release notes
- Project documentation

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

Thank you for contributing to the Nephio Intent Operator!