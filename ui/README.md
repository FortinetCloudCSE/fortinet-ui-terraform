# Terraform Configuration UI

A modern web application for generating Terraform configuration files for FortiGate Autoscale deployments.

**Built with:** React 18 + FastAPI + Python

---

## 🚀 Quick Start (2 Commands)

```bash
# Terminal 1: Backend
cd backend && uv run uvicorn app.main:app --reload

# Terminal 2: Frontend
cd frontend && npm run dev
```

**Visit:** http://localhost:5173

✅ **No database needed** - works with mock data out of the box!

---

## 📖 Documentation

**New to this project? Start here:** 👉 **[START_HERE.md](START_HERE.md)**

### Essential Guides

| Document | Purpose | Read When... |
|----------|---------|-------------|
| **[START_HERE.md](START_HERE.md)** | 🎯 Complete orientation | You're new to the project |
| **[QUICKSTART.md](QUICKSTART.md)** | ⚡ Run the app in 2 minutes | You want to see it working NOW |
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | 📚 Comprehensive developer guide | You're ready to start coding |
| **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** | 📊 Big picture overview | You want to understand everything |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | 🏗️ System design diagrams | You need to understand how it works |
| **[HTML_VS_REACT.md](HTML_VS_REACT.md)** | 🔄 Before/after comparison | You're curious what changed |
| **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** | 🛠️ Detailed migration steps | You're ready to add more features |

---

## 🎯 What This App Does

- **Generates Terraform configurations** for FortiGate Autoscale deployments
- **Provides form-based input** for all Terraform variables
- **Validates configuration values** before generation
- **Supports multiple templates** (existing_vpc_resources, autoscale_template, ha_pair)
- **Integrates with AWS** to discover regions, AZs, and keypairs

---

## 💻 Tech Stack

### Backend
- **FastAPI** - Modern Python web framework
- **Pydantic v2** - Data validation
- **boto3** - AWS SDK for resource discovery
- **uv** - Fast Python package manager

### Frontend
- **React 18** - UI library
- **Vite** - Build tool and dev server
- **Modern JavaScript** - ES6+ with hooks

---

## 📁 Project Structure

```
react_fastapi/
├── backend/                    # FastAPI REST API
│   ├── app/
│   │   ├── main.py            # FastAPI app setup
│   │   ├── config.py          # Settings configuration
│   │   ├── schemas.py         # Pydantic models
│   │   ├── mock_data.py       # Mock data service
│   │   └── api/
│   │       └── root.py        # Main endpoint
│   └── pyproject.toml         # Python dependencies (uv)
│
├── frontend/                   # React application
│   ├── src/
│   │   ├── App.jsx            # Main app component
│   │   ├── components/        # React components
│   │   └── services/          # API service layer
│   └── package.json           # Node dependencies
│
└── docs/                       # You are here!
    ├── START_HERE.md          # 👈 Begin here!
    ├── QUICKSTART.md
    ├── GETTING_STARTED.md
    └── ... (other guides)
```

---

## ✨ Features

### Current Features (Working Now)
- ✅ Template selection
- ✅ Dynamic form generation
- ✅ AWS resource discovery
- ✅ Configuration validation
- ✅ tfvars file generation
- ✅ Responsive design
- ✅ Real-time field updates

### Coming Soon
- 🔄 Template comparison view
- 🔄 Configuration history
- 🔄 Terraform plan preview
- 🔄 Multi-environment support
- 🔄 User authentication
- 🔄 Saved configurations

---

## 🚦 Development Status

**Current Phase:** ✅ Core Setup Complete

| Phase | Status |
|-------|--------|
| Backend structure | ✅ Complete |
| Frontend structure | ✅ Complete |
| Schema parsing | ✅ Complete |
| AWS integration | ✅ Complete |
| Configuration generation | ✅ Complete |
| Validation | 🔄 In progress |
| Authentication | 📋 Planned |

---

## 🔧 Prerequisites

- **Python 3.11+** for backend
- **Node.js 18+** for frontend
- **uv** for Python package management: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- **AWS credentials** (optional - for resource discovery)

---

## 📊 API Endpoints

### Current Endpoints

- `GET /api/terraform/schema` - Get template schema and fields
- `GET /api/terraform/config/load` - Load existing configuration
- `POST /api/terraform/config/save` - Save configuration
- `GET /api/aws/regions` - List AWS regions
- `GET /api/aws/availability-zones` - List AZs for region
- `GET /api/aws/keypairs` - List keypairs for region
- `GET /health` - Health check
- `GET /api/status` - API status

### Coming Soon

- `POST /api/terraform/validate` - Validate configuration
- `POST /api/terraform/generate` - Generate tfvars file
- `GET /api/aws/vpcs` - List existing VPCs

**View full API documentation:** http://127.0.0.1:8000/docs (when backend is running)

---

## 🎓 Learning Resources

### For This Project
- **START_HERE.md** - Your complete orientation guide
- **GETTING_STARTED.md** - Developer handbook
- **ARCHITECTURE.md** - System design explained

### External Resources
- **FastAPI:** https://fastapi.tiangolo.com/tutorial/
- **React:** https://react.dev/learn
- **Pydantic:** https://docs.pydantic.dev/latest/
- **uv:** https://docs.astral.sh/uv/

---

## 🐛 Troubleshooting

**Backend won't start?**
```bash
cd backend && uv sync
```

**Frontend won't start?**
```bash
cd frontend && npm install
```

**CORS errors?**
Check `backend/app/config.py` - frontend URL should be in `cors_origins`

**More help:** See [GETTING_STARTED.md](GETTING_STARTED.md) troubleshooting section

---

## 📈 Migration from Original App

This is a modernized version of `sag_fastapi_app` with:

| Old | New | Benefit |
|-----|-----|---------|
| Server-rendered HTML | React components | Instant UI updates |
| Full page reloads | Single Page App | Better UX |
| Mixed concerns | Separated frontend/backend | Easier development |
| pip | uv package manager | Faster installs |
| Manual testing | Auto-generated API docs | Better DX |

See [HTML_VS_REACT.md](HTML_VS_REACT.md) for detailed comparison.

---

## 🤝 Contributing

This is a personal project, but suggestions are welcome!

1. Read the documentation
2. Understand the architecture
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📝 License

Private project - all rights reserved.

---

## 🎯 Next Steps

1. **Read [START_HERE.md](START_HERE.md)** for complete orientation
2. **Follow [QUICKSTART.md](QUICKSTART.md)** to run the app
3. **Use [GETTING_STARTED.md](GETTING_STARTED.md)** to start developing
4. **Enjoy building!** 🚀

---

**Questions?** Check the documentation - everything is covered! 📚

**Ready to code?** Start with [START_HERE.md](START_HERE.md)! 🎯
