# Terraform Configuration UI - Frontend

React 18 frontend application built with Vite.

## Tech Stack

- **React 18** - UI library with hooks
- **Vite** - Build tool and dev server
- **Vanilla CSS** - Component styling (no framework)
- **Fetch API** - HTTP requests to backend

## Getting Started

### Prerequisites
- Node.js 18+ and npm

### Installation

```bash
npm install
```

### Development

Start the dev server:
```bash
npm run dev
```

The app will be available at http://localhost:3000

Hot reload is enabled - changes appear immediately.

### Build for Production

```bash
npm run build
```

Output goes to `dist/` directory.

Preview production build:
```bash
npm run preview
```

## Project Structure

```
src/
├── components/          # React components
│   ├── TerraformConfig.jsx     # Main configuration form
│   └── TerraformConfig.css
│
├── services/           # API layer
│   └── api.js                  # Backend communication
│
├── App.jsx            # Main application component
├── App.css            # Main app styles
├── main.jsx           # React entry point
└── index.css          # Global styles
```

## Components

### App.jsx
Main application component that:
- Fetches schema from backend on mount
- Manages loading/error states
- Renders configuration form
- Handles template selection

**Props:** None (top-level component)

**State:**
- `schema` - Template schema from API
- `config` - Current configuration values
- `loading` - Loading state boolean
- `error` - Error message string
- `template` - Currently selected template

### TerraformConfig.jsx
Main configuration form for Terraform variables.

**Props:**
- `template` - Template name to configure
- `onConfigChange` - Callback when configuration changes

**Features:**
- Dynamic form field generation
- Field validation
- Grouped configuration options
- Template selection dropdown

## API Service (api.js)

Centralized API communication layer.

### Methods

**getSchema(template)**
- Fetches template schema
- Optional template parameter
- Returns: SchemaResponse with groups and fields

**getConfig(template)**
- Loads saved configuration
- Returns: Configuration values

**saveConfig(template, config)**
- Saves configuration to file
- Returns: Success status

### Usage Example

```javascript
import api from './services/api';

// Get template schema
const schema = await api.getSchema('existing_vpc_resources');

// Load configuration
const config = await api.getConfig('existing_vpc_resources');

// Save configuration
await api.saveConfig('existing_vpc_resources', configValues);
```

## Styling

### CSS Organization
- Each component has its own CSS file
- `App.css` - Main layout and utilities
- `index.css` - Global resets
- Component CSS - Scoped to component

### Color Variables
```css
Primary Blue:     #013369
Secondary Blue:   #0366d6
Light Blue:       #e8f4f8
Success Green:    #28a745
White:            #ffffff
Page Background:  #f5f5f5
Text Dark:        #333333
Text Medium:      #666666
Border:           #dddddd
```

### Responsive Design
- Desktop-first approach
- Mobile breakpoint: 768px
- Flexbox and Grid layouts
- Fluid typography

## Configuration

### Vite Config (vite.config.js)

```javascript
{
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      }
    }
  }
}
```

### API Base URL

Configured in `src/services/api.js`:
```javascript
const API_BASE_URL = 'http://127.0.0.1:8000';
```

Change this for production deployment.

## Development Workflow

### Making Changes

1. **Edit component:**
   ```
   src/components/MyComponent.jsx
   ```

2. **Changes appear immediately** (hot reload)

3. **Check browser console** (F12) for errors

4. **View in browser** at http://localhost:3000

### Adding New Component

1. Create `.jsx` file in `src/components/`
2. Create matching `.css` file
3. Import in `App.jsx`:
   ```javascript
   import MyComponent from './components/MyComponent';
   ```

4. Use in JSX:
   ```jsx
   <MyComponent prop1="value" />
   ```

### Adding New API Call

1. Add method in `api.js`:
   ```javascript
   export const api = {
     newMethod: async () => {
       return apiFetch('/new-endpoint');
     }
   };
   ```

2. Call from component:
   ```javascript
   const data = await api.newMethod();
   ```

## Common Tasks

### Fetch Data on Component Mount
```javascript
useEffect(() => {
  const fetchData = async () => {
    try {
      const result = await api.getData();
      setData(result);
    } catch (error) {
      setError(error.message);
    }
  };
  fetchData();
}, []);
```

### Handle Button Click
```javascript
const handleClick = async () => {
  try {
    const result = await api.doSomething();
    console.log(result);
  } catch (error) {
    console.error(error);
  }
};

<button onClick={handleClick}>Click Me</button>
```

### Conditional Rendering
```javascript
{loading && <div>Loading...</div>}
{error && <div>Error: {error}</div>}
{data && <div>{data.message}</div>}
```

### List Rendering
```javascript
{items.map(item => (
  <ItemComponent key={item.id} item={item} />
))}
```

## Debugging

### Browser Console (F12)
- View console.log() output
- See API request/response
- Check for errors
- Inspect network tab

### React DevTools
- Install browser extension
- Inspect component tree
- View props and state
- Track re-renders

### Common Issues

**Blank page:**
- Check console for errors
- Verify backend is running
- Check API_BASE_URL in api.js

**CORS errors:**
- Backend must be running
- Check CORS_ORIGINS in backend .env
- Verify frontend URL matches allowed origins

**API errors:**
- Check network tab (F12)
- Verify backend endpoint exists
- Check response status code

**Component not updating:**
- Check state updates
- Verify useEffect dependencies
- Look for key warnings

## Testing (Future)

Will use Vitest and React Testing Library:

```bash
# Install testing dependencies
npm install --save-dev vitest @testing-library/react @testing-library/jest-dom

# Run tests
npm test
```

## Building for Production

```bash
# Create optimized build
npm run build

# Output in dist/
# Files are minified and optimized
# Ready to deploy to static hosting
```

### Deployment Options
- Vercel (recommended for Vite)
- Netlify
- GitHub Pages
- AWS S3 + CloudFront
- Any static hosting

## Performance Tips

- Keep components small and focused
- Use React.memo for expensive components
- Avoid prop drilling (consider context)
- Lazy load routes (React.lazy)
- Optimize images
- Code splitting

## Resources

- **React Docs:** https://react.dev
- **Vite Docs:** https://vitejs.dev
- **React Hooks:** https://react.dev/reference/react
- **CSS Tricks:** https://css-tricks.com
