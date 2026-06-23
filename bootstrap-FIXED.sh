#!/bin/bash

# Trunk-Based Development POC - Bootstrap Script (FIXED)
# This script creates the complete project structure with all files

set -e  # Exit on error

PROJECT_NAME="tbd-poc"
GITHUB_USERNAME="${1:-your-username}"

echo "================================"
echo "TBD POC Bootstrap Script"
echo "================================"
echo ""

# Create project directory
echo "📁 Creating project directory: $PROJECT_NAME"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Initialize git first (before npm)
echo "🔧 Initializing git repository"
git init > /dev/null 2>&1

# Create package.json with correct scripts FIRST
echo "📦 Creating package.json with test scripts"
cat > package.json << 'EOF'
{
  "name": "tbd-poc",
  "version": "0.1.0",
  "description": "Trunk-Based Development POC with GitHub Actions",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "echo 'Linting...'",
    "build": "echo 'Build successful'"
  },
  "keywords": ["tbd", "ci-cd", "github-actions"],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.0",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "@babel/preset-env": "^7.20.0",
    "babel-jest": "^29.0.0",
    "jest": "^29.0.0",
    "nodemon": "^2.0.0",
    "supertest": "^6.3.0"
  }
}
EOF

# Install dependencies
echo "📥 Installing dependencies..."
npm install 2>/dev/null

# Create directory structure
echo "📂 Creating directory structure"
mkdir -p src/{config,routes,services,utils}
mkdir -p tests
mkdir -p k8s
mkdir -p .github/workflows

# Create .gitignore
echo "🚫 Creating .gitignore"
cat > .gitignore << 'EOF'
node_modules/
npm-debug.log*
.env
.env.local
.DS_Store
dist/
coverage/
*.log
.idea/
.vscode/
build/
EOF

# Create .env
echo "⚙️  Creating .env"
cat > .env << 'EOF'
NODE_ENV=development
PORT=3000
DEBUG=tbd-poc:*
EOF

# Create Feature Flags Configuration
echo "🚩 Creating feature flags configuration"
cat > src/config/flags.json << 'EOF'
{
  "features": {
    "new_user_profile": {
      "enabled": false,
      "description": "New user profile endpoint with additional fields"
    },
    "rate_limiting": {
      "enabled": true,
      "description": "Enable rate limiting on API endpoints"
    },
    "advanced_analytics": {
      "enabled": false,
      "description": "Advanced user analytics dashboard"
    },
    "dark_mode": {
      "enabled": true,
      "description": "Dark mode UI support"
    },
    "user_verification": {
      "enabled": false,
      "description": "Email verification for new users"
    }
  },
  "canary": {
    "new_user_profile_percent": 0,
    "advanced_analytics_percent": 0
  }
}
EOF

# Create Feature Flags Utility
echo "🛠️  Creating feature flags utility"
cat > src/utils/featureFlags.js << 'EOF'
const fs = require('fs');
const path = require('path');

class FeatureFlags {
  constructor() {
    this.flagsPath = path.join(__dirname, '../config/flags.json');
    this.loadFlags();
  }

  loadFlags() {
    try {
      const data = fs.readFileSync(this.flagsPath, 'utf8');
      this.flags = JSON.parse(data);
    } catch (error) {
      console.error('Error loading feature flags:', error);
      this.flags = { features: {}, canary: {} };
    }
  }

  isFeatureEnabled(featureName) {
    this.loadFlags();
    const feature = this.flags.features[featureName];
    return feature?.enabled ?? false;
  }

  getFeature(featureName) {
    this.loadFlags();
    return this.flags.features[featureName] || null;
  }

  getAllFeatures() {
    this.loadFlags();
    return this.flags.features;
  }

  toggleFeature(featureName, enabled) {
    this.loadFlags();
    if (this.flags.features[featureName]) {
      this.flags.features[featureName].enabled = enabled;
      this.saveFlags();
      return true;
    }
    return false;
  }

  isFeatureEnabledForUser(featureName, userId) {
    const feature = this.flags.features[featureName];
    if (!feature?.enabled) return false;

    const canaryKey = `${featureName}_percent`;
    const canaryPercent = this.flags.canary[canaryKey] ?? 100;

    const hash = userId.split('').reduce((h, c) => h + c.charCodeAt(0), 0);
    return (hash % 100) < canaryPercent;
  }

  saveFlags() {
    try {
      fs.writeFileSync(this.flagsPath, JSON.stringify(this.flags, null, 2));
    } catch (error) {
      console.error('Error saving feature flags:', error);
    }
  }
}

module.exports = new FeatureFlags();
EOF

# Create User Service
echo "👥 Creating user service"
cat > src/services/userService.js << 'EOF'
const featureFlags = require('../utils/featureFlags');

class UserService {
  constructor() {
    this.users = [
      { id: '1', name: 'Alice', email: 'alice@example.com' },
      { id: '2', name: 'Bob', email: 'bob@example.com' }
    ];
  }

  getAllUsers() {
    return this.users;
  }

  getUserById(id) {
    return this.users.find(u => u.id === id) || null;
  }

  createUser(userData) {
    if (!userData.name || !userData.email) {
      throw new Error('Name and email are required');
    }

    if (!this.isValidEmail(userData.email)) {
      throw new Error('Invalid email format');
    }

    const newUser = {
      id: String(this.users.length + 1),
      ...userData
    };

    if (featureFlags.isFeatureEnabled('new_user_profile')) {
      newUser.avatar = userData.avatar || 'default.png';
      newUser.bio = userData.bio || '';
      newUser.joinDate = new Date().toISOString();
    }

    this.users.push(newUser);
    return newUser;
  }

  updateUser(id, userData) {
    const user = this.getUserById(id);
    if (!user) {
      throw new Error('User not found');
    }

    Object.assign(user, userData);
    return user;
  }

  deleteUser(id) {
    const index = this.users.findIndex(u => u.id === id);
    if (index === -1) {
      throw new Error('User not found');
    }

    const deleted = this.users.splice(index, 1);
    return deleted[0];
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  getAnalytics(userId) {
    if (!featureFlags.isFeatureEnabledForUser('advanced_analytics', userId)) {
      return { available: false, reason: 'Feature not enabled for this user' };
    }

    return {
      available: true,
      userId,
      visits: Math.floor(Math.random() * 100),
      lastActive: new Date().toISOString()
    };
  }

  verifyUser(id) {
    if (!featureFlags.isFeatureEnabled('user_verification')) {
      return { verified: false, reason: 'Feature not available' };
    }

    const user = this.getUserById(id);
    if (!user) throw new Error('User not found');

    user.verified = true;
    user.verifiedAt = new Date().toISOString();
    return user;
  }
}

module.exports = new UserService();
EOF

# Create User Routes
echo "🛣️  Creating user routes"
cat > src/routes/userRoutes.js << 'EOF'
const express = require('express');
const userService = require('../services/userService');

const router = express.Router();

router.get('/', (req, res) => {
  try {
    const users = userService.getAllUsers();
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/:id', (req, res) => {
  try {
    const user = userService.getUserById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', (req, res) => {
  try {
    const newUser = userService.createUser(req.body);
    res.status(201).json(newUser);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.put('/:id', (req, res) => {
  try {
    const updatedUser = userService.updateUser(req.params.id, req.body);
    res.json(updatedUser);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.delete('/:id', (req, res) => {
  try {
    const deletedUser = userService.deleteUser(req.params.id);
    res.json({ message: 'User deleted', user: deletedUser });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/:id/analytics', (req, res) => {
  try {
    const analytics = userService.getAnalytics(req.params.id);
    res.json(analytics);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
EOF

# Create Server
echo "🖥️  Creating express server"
cat > src/server.js << 'EOF'
require('dotenv').config();
const express = require('express');
const userRoutes = require('./routes/userRoutes');
const featureFlags = require('./utils/featureFlags');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/flags', (req, res) => {
  res.json(featureFlags.getAllFeatures());
});

app.post('/admin/flags/:featureName/:enabled', (req, res) => {
  const { featureName, enabled } = req.params;
  const isEnabled = enabled === 'true';

  const success = featureFlags.toggleFeature(featureName, isEnabled);

  if (success) {
    res.json({ message: `Feature '${featureName}' set to ${isEnabled}` });
  } else {
    res.status(404).json({ error: 'Feature not found' });
  }
});

app.use('/api/users', userRoutes);

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error'
  });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}

module.exports = app;
EOF

# Create jest.config.js
echo "🧪 Creating jest configuration"
cat > jest.config.js << 'EOF'
module.exports = {
  testEnvironment: 'node',
  coveragePathIgnorePatterns: ['/node_modules/', '/tests/'],
  testMatch: ['**/tests/**/*.test.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/server.js'
  ],
  coverageThreshold: {
    global: {
      branches: 50,
      functions: 50,
      lines: 50,
      statements: 50
    }
  }
};
EOF

# Create .babelrc
echo "⚙️  Creating babel configuration"
cat > .babelrc << 'EOF'
{
  "presets": [["@babel/preset-env", { "targets": { "node": "current" } }]]
}
EOF

# Create test files
echo "✅ Creating test files"

# Unit tests
cat > tests/userService.test.js << 'TESTEOF'
const userService = require('../src/services/userService');
const featureFlags = require('../src/utils/featureFlags');

describe('UserService', () => {
  beforeEach(() => {
    userService.users = [
      { id: '1', name: 'Alice', email: 'alice@example.com' },
      { id: '2', name: 'Bob', email: 'bob@example.com' }
    ];
  });

  describe('getAllUsers', () => {
    test('should return all users', () => {
      const users = userService.getAllUsers();
      expect(users.length).toBe(2);
    });
  });

  describe('getUserById', () => {
    test('should return user when id exists', () => {
      const user = userService.getUserById('1');
      expect(user).not.toBeNull();
      expect(user.name).toBe('Alice');
    });

    test('should return null when id does not exist', () => {
      const user = userService.getUserById('999');
      expect(user).toBeNull();
    });
  });

  describe('createUser', () => {
    test('should create user with valid data', () => {
      const newUser = userService.createUser({
        name: 'Charlie',
        email: 'charlie@example.com'
      });

      expect(newUser.name).toBe('Charlie');
      expect(newUser.id).toBeDefined();
    });

    test('should throw error for missing name', () => {
      expect(() => {
        userService.createUser({ email: 'test@example.com' });
      }).toThrow('Name and email are required');
    });

    test('should throw error for invalid email', () => {
      expect(() => {
        userService.createUser({ name: 'Test', email: 'invalid' });
      }).toThrow('Invalid email format');
    });
  });

  describe('updateUser', () => {
    test('should update existing user', () => {
      const updated = userService.updateUser('1', { name: 'Alice Updated' });
      expect(updated.name).toBe('Alice Updated');
    });
  });

  describe('deleteUser', () => {
    test('should delete user', () => {
      const deleted = userService.deleteUser('1');
      expect(deleted.id).toBe('1');
      expect(userService.getAllUsers().length).toBe(1);
    });
  });

  describe('isValidEmail', () => {
    test('should validate correct email', () => {
      expect(userService.isValidEmail('test@example.com')).toBe(true);
    });

    test('should reject invalid email', () => {
      expect(userService.isValidEmail('invalid')).toBe(false);
    });
  });
});
TESTEOF

# Integration tests
cat > tests/api.integration.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/server');
const userService = require('../src/services/userService');
const featureFlags = require('../src/utils/featureFlags');

describe('User API Integration Tests', () => {
  beforeEach(() => {
    userService.users = [
      { id: '1', name: 'Alice', email: 'alice@example.com' },
      { id: '2', name: 'Bob', email: 'bob@example.com' }
    ];
    featureFlags.flags.features.new_user_profile.enabled = false;
  });

  describe('GET /api/users', () => {
    test('should return all users', async () => {
      const response = await request(app).get('/api/users');
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBe(2);
    });
  });

  describe('GET /api/users/:id', () => {
    test('should return user by id', async () => {
      const response = await request(app).get('/api/users/1');
      expect(response.status).toBe(200);
      expect(response.body.name).toBe('Alice');
    });

    test('should return 404 for non-existent user', async () => {
      const response = await request(app).get('/api/users/999');
      expect(response.status).toBe(404);
    });
  });

  describe('POST /api/users', () => {
    test('should create new user', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ name: 'Charlie', email: 'charlie@example.com' });

      expect(response.status).toBe(201);
      expect(response.body.name).toBe('Charlie');
    });

    test('should return 400 for invalid data', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ name: 'Charlie' });

      expect(response.status).toBe(400);
    });
  });

  describe('GET /health', () => {
    test('should return health status', async () => {
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('ok');
    });
  });

  describe('GET /flags', () => {
    test('should return feature flags', async () => {
      const response = await request(app).get('/flags');
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('new_user_profile');
    });
  });
});
TESTEOF

# Create GitHub Actions workflows
echo "⚙️  Creating GitHub Actions workflows"

cat > .github/workflows/pr-checks.yml << 'EOF'
name: PR Checks

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x]

    steps:
      - uses: actions/checkout@v3
      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Lint
        run: npm run lint
      - name: Run tests
        run: npm test
      - name: Check test coverage
        run: npm run test:coverage
      - name: Build
        run: npm run build
EOF

cat > .github/workflows/main-deploy.yml << 'EOF'
name: Main Branch - Test & Deploy

on:
  push:
    branches: [main]

env:
  REGISTRY: docker.io
  IMAGE_NAME: ${{ github.actor }}/tbd-poc

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x]

    steps:
      - uses: actions/checkout@v3
      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Run all tests
        run: npm test
      - name: Generate coverage report
        run: npm run test:coverage

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      - name: Build Docker image
        run: docker build -t tbd-poc:${{ github.sha }} -t tbd-poc:latest .
      - name: Log build status
        run: echo "✅ Build completed successfully"
EOF

# Create Dockerfile
echo "🐳 Creating Dockerfile"
cat > Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src ./src
COPY package*.json ./

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

CMD ["node", "src/server.js"]
EOF

# Create .dockerignore
echo "🚫 Creating .dockerignore"
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
tests
.git
.gitignore
.github
.env
.DS_Store
k8s
README.md
jest.config.js
.babelrc
EOF

# Create K8s manifests
echo "☸️  Creating Kubernetes manifests"

cat > k8s/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tbd-poc
  namespace: default
  labels:
    app: tbd-poc
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: tbd-poc
  template:
    metadata:
      labels:
        app: tbd-poc
    spec:
      containers:
      - name: tbd-poc
        image: docker.io/your-username/tbd-poc:latest
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
EOF

cat > k8s/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: tbd-poc
  labels:
    app: tbd-poc
spec:
  type: LoadBalancer
  selector:
    app: tbd-poc
  ports:
  - name: http
    port: 80
    targetPort: http
EOF

cat > k8s/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app: tbd-poc
EOF

# Create README
echo "📖 Creating README"
cat > README.md << 'EOF'
# Trunk-Based Development POC

A practical demonstration of Trunk-Based Development with GitHub Actions, feature flags, and Kubernetes deployment.

## Quick Start

```bash
npm install
npm test
npm run dev
```

## API Endpoints

- `GET /health` - Health check
- `GET /flags` - View all feature flags
- `GET /api/users` - List all users
- `POST /api/users` - Create new user
- `GET /api/users/:id` - Get user by ID
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user
- `POST /admin/flags/:featureName/:enabled` - Toggle feature flag

## Feature Flags

```bash
curl -X POST http://localhost:3000/admin/flags/new_user_profile/true
```

## Testing

```bash
npm test                 # Run tests
npm run test:watch      # Watch mode
npm run test:coverage   # Coverage report
```

## Learn More

- `01-TrunkBasedDevelopment-StudyGuide.md` - TBD theory
- `02-TBD-POC-SetupGuide.md` - Setup guide
- `03-TBD-QuickReference.md` - Quick reference
EOF

# Initialize git repository
echo "🔧 Finalizing git repository"
git add . > /dev/null 2>&1
git commit -m "Initial commit: TBD POC setup" > /dev/null 2>&1

echo ""
echo "================================"
echo "✅ Bootstrap Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. cd $PROJECT_NAME"
echo "2. npm test              # Run tests (should PASS now!)"
echo "3. npm run dev           # Start development server"
echo "4. git remote add origin <your-repo-url>"
echo "5. git push -u origin main"
echo ""
echo "📚 For detailed guides, see:"
echo "- 01-TrunkBasedDevelopment-StudyGuide.md"
echo "- 02-TBD-POC-SetupGuide.md"
echo "- 03-TBD-QuickReference.md"
echo ""
