import React, { useState, useEffect, useRef, useMemo } from 'react';
import api from '../services/api';
import FormGroup from './FormGroup';
import TemplateRegistration from './TemplateRegistration';
import DriftResolution from './DriftResolution';
import './TerraformConfig.css';
import Anser from 'anser';

function TerraformConfig() {
  const [template, setTemplate] = useState('');
  const [schema, setSchema] = useState(null);
  const [config, setConfig] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [awsCredentialsValid, setAwsCredentialsValid] = useState(false);
  const [gcpCredentialsValid, setGcpCredentialsValid] = useState(false);
  const [saving, setSaving] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [generatedContent, setGeneratedContent] = useState(null);
  const [hasSavedConfig, setHasSavedConfig] = useState(false);
  const [savingToTemplate, setSavingToTemplate] = useState(false);
  const [building, setBuilding] = useState(false);
  const [buildOutput, setBuildOutput] = useState('');
  const [showBuildTerminal, setShowBuildTerminal] = useState(false);
  const [showBuildSteps, setShowBuildSteps] = useState(false);
  const [inheritedFields, setInheritedFields] = useState([]);
  const [derivedFields, setDerivedFields] = useState([]);
  const [showSaveLogModal, setShowSaveLogModal] = useState(false);
  const [registeredTemplates, setRegisteredTemplates] = useState([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState(null);
  const [driftStatus, setDriftStatus] = useState(null);
  const [driftEntries, setDriftEntries] = useState([]);
  const [driftDismissed, setDriftDismissed] = useState(false);
  const [showRegistration, setShowRegistration] = useState(false);
  const [showDriftResolution, setShowDriftResolution] = useState(false);
  const terminalOutputRef = useRef(null);

  // Load registered templates on mount
  useEffect(() => {
    loadRegisteredTemplates();
  }, []);

  // Load schema and config on mount or template change
  useEffect(() => {
    loadSchemaAndConfig();
    checkAwsCredentials();
    checkGcpCredentials();
  }, [template]);

  // Match current template to DB record when registry loads
  useEffect(() => {
    if (registeredTemplates.length > 0) {
      const match = registeredTemplates.find(t => t.name === template);
      if (match) {
        setSelectedTemplateId(match.id);
      }
    }
  }, [registeredTemplates]);

  // Check drift status when selected template ID changes
  useEffect(() => {
    if (selectedTemplateId) {
      checkDriftStatus(selectedTemplateId);
    } else {
      setDriftStatus(null);
    }
  }, [selectedTemplateId]);

  const checkAwsCredentials = async () => {
    try {
      const status = await api.aws.checkCredentials();
      setAwsCredentialsValid(status.valid);
    } catch (err) {
      console.warn('AWS credentials not available:', err);
      setAwsCredentialsValid(false);
    }
  };

  const checkGcpCredentials = async () => {
    try {
      const status = await api.gcp.checkCredentials();
      setGcpCredentialsValid(status.valid);
      return status;
    } catch (err) {
      console.warn('GCP credentials not available:', err);
      setGcpCredentialsValid(false);
      return { valid: false };
    }
  };

  const loadRegisteredTemplates = async () => {
    try {
      const templates = await api.templates.list();
      setRegisteredTemplates(templates);
      // Auto-select first template if none selected
      if (templates.length > 0 && !template) {
        setTemplate(templates[0].name);
        setSelectedTemplateId(templates[0].id);
      }
    } catch (err) {
      console.warn('Template registry not available:', err);
      setRegisteredTemplates([]);
    }
  };

  const checkDriftStatus = async (templateId) => {
    try {
      const report = await api.templates.getDrift(templateId);
      setDriftStatus(report.status);
      setDriftEntries(report.entries || []);
      setDriftDismissed(false);
    } catch (err) {
      console.warn('Drift check failed:', err);
      setDriftStatus(null);
      setDriftEntries([]);
    }
  };

  const handleTemplateChange = (value) => {
    setTemplate(value);
    const dbTemplate = registeredTemplates.find(t => t.name === value);
    setSelectedTemplateId(dbTemplate ? dbTemplate.id : null);
  };

  const loadSchemaAndConfig = async () => {
    if (!template) {
      setLoading(false);
      setSchema(null);
      return;
    }
    setLoading(true);
    setError(null);

    try {
      // Load schema
      const schemaData = await api.terraform.getSchema(template);
      setSchema(schemaData);

      // Try to load saved config
      const configData = await api.terraform.loadConfig(template);
      let newConfig;
      if (configData.success && configData.config) {
        newConfig = configData.config;
        setHasSavedConfig(true);
        setInheritedFields(configData.inherited_fields || []);
      } else {
        // Initialize with default values from schema
        const defaults = {};
        schemaData.groups.forEach(group => {
          group.fields.forEach(field => {
            defaults[field.name] = field.default_value;
          });
        });
        newConfig = { ...defaults, ...configData.config };
        setHasSavedConfig(false);
        setInheritedFields(configData.inherited_fields || []);
      }

      // For GCP templates, auto-populate gcp_project from credentials
      if (template.startsWith('gcp/') && !newConfig.gcp_project) {
        const gcpStatus = await checkGcpCredentials();
        if (gcpStatus.valid && gcpStatus.project_id) {
          newConfig.gcp_project = gcpStatus.project_id;
        }
      }

      // Load inherited defaults from sibling existing_vpc_resources template
      const dbTemplate = registeredTemplates.find(t => t.name === template);
      if (dbTemplate) {
        try {
          const inherited = await api.templates.getInheritedDefaults(dbTemplate.id);
          if (inherited.defaults && Object.keys(inherited.defaults).length > 0) {
            // Apply as defaults — only overwrite fields not already set by user
            Object.entries(inherited.defaults).forEach(([k, v]) => {
              if (newConfig[k] === undefined || newConfig[k] === null || newConfig[k] === '' || newConfig[k] === false) {
                newConfig[k] = v;
              }
            });
            setDerivedFields(Object.keys(inherited.defaults));
          }
        } catch (err) {
          console.warn('Could not load inherited defaults:', err);
        }
      }

      setConfig(newConfig);
    } catch (err) {
      setError(err.message);
      console.error('Error loading schema:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleFieldChange = (fieldName, value) => {
    setConfig(prev => ({
      ...prev,
      [fieldName]: value
    }));
  };

  // Filter config to exclude UI-only fields that shouldn't be in terraform.tfvars
  const getTfvarsConfig = () => {
    if (!schema) return config;
    const excludeFields = new Set();
    schema.groups.forEach(group => {
      group.fields.forEach(field => {
        if (field.type === 'output' || field.tfvars_exclude === 'true') {
          excludeFields.add(field.name);
        }
      });
    });
    const filtered = {};
    for (const [key, value] of Object.entries(config)) {
      if (!excludeFields.has(key)) {
        filtered[key] = value;
      }
    }
    return filtered;
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.terraform.saveConfig(template, getTfvarsConfig());
      setHasSavedConfig(true);
      alert('Configuration saved successfully!');
    } catch (err) {
      alert(`Error saving configuration: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const handleReset = async () => {
    if (!confirm('Are you sure you want to reset to default values? This will delete your saved configuration.')) {
      return;
    }

    try {
      await api.terraform.deleteConfig(template);
      // Reload schema and defaults
      await loadSchemaAndConfig();
      alert('Configuration reset to defaults successfully!');
    } catch (err) {
      alert(`Error resetting configuration: ${err.message}`);
    }
  };

  const handleGenerate = async () => {
    setGenerating(true);
    try {
      const result = await api.terraform.generateTfvars(template, getTfvarsConfig());
      setGeneratedContent(result);
    } catch (err) {
      alert(`Error generating tfvars: ${err.message}`);
    } finally {
      setGenerating(false);
    }
  };

  const handleDownload = () => {
    if (!generatedContent) return;

    const blob = new Blob([generatedContent.content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = generatedContent.filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleClear = () => {
    setGeneratedContent(null);
  };

  const handleSaveToTemplate = async () => {
    setSavingToTemplate(true);
    try {
      const result = await api.terraform.saveToTemplate(template, getTfvarsConfig());
      alert(`Success! terraform.tfvars saved to:\n${result.file}`);
    } catch (err) {
      alert(`Error saving to template directory: ${err.message}`);
    } finally {
      setSavingToTemplate(false);
    }
  };

  const handleBuild = async () => {
    if (!confirm('This will run terraform apply -auto-approve. Are you sure you want to build the infrastructure?')) {
      return;
    }

    setBuilding(true);
    setBuildOutput('');
    setShowBuildTerminal(true);

    try {
      await api.terraform.buildInfrastructure(template, (data) => {
        setBuildOutput(prev => prev + data);
      });
    } catch (err) {
      setBuildOutput(prev => prev + `\n\nError: ${err.message}\n`);
    } finally {
      setBuilding(false);
    }
  };

  const handleBuildStep = async (step) => {
    const confirmMessages = {
      apply: 'This will run terraform apply -auto-approve. Continue?',
      destroy: 'This will DESTROY all infrastructure. Are you sure?',
    };

    if (confirmMessages[step] && !confirm(confirmMessages[step])) {
      return;
    }

    setBuilding(true);
    setBuildOutput('');
    setShowBuildTerminal(true);

    try {
      await api.terraform.buildStep(template, step, (data) => {
        setBuildOutput(prev => prev + data);
      });
    } catch (err) {
      setBuildOutput(prev => prev + `\n\nError: ${err.message}\n`);
    } finally {
      setBuilding(false);
    }
  };

  const handleCloseBuildTerminal = () => {
    setShowBuildTerminal(false);
    setBuildOutput('');
  };

  const handleSaveLog = () => {
    if (!buildOutput) return;
    setShowSaveLogModal(true);
  };

  const handleSaveLogConfirm = async (mode) => {
    setShowSaveLogModal(false);
    try {
      const result = await api.terraform.saveLog(template, buildOutput, mode);
      alert(`Log saved successfully to:\n${result.file}`);
    } catch (err) {
      alert(`Error saving log: ${err.message}`);
    }
  };

  // Convert ANSI codes to HTML spans with inline styles
  const colorizedOutput = useMemo(() => {
    if (!buildOutput) return [];

    // Color mapping to brighten dark colors for better contrast on black background
    const brightenColor = (rgbString) => {
      if (!rgbString) return null;

      // Parse RGB values
      const match = rgbString.match(/(\d+),\s*(\d+),\s*(\d+)/);
      if (!match) return rgbString;

      let [_, r, g, b] = match.map(Number);

      // Detect dark blue (low R, low G, moderate B) and brighten it
      if (b > r && b > g && b < 150) {
        // Brighten blue significantly for better contrast
        r = Math.min(100, r * 1.5);
        g = Math.min(150, g * 1.5);
        b = Math.min(255, b * 2.2);
      }
      // Brighten other dark colors
      else if (r < 100 && g < 100 && b < 100) {
        r = Math.min(255, r * 1.8);
        g = Math.min(255, g * 1.8);
        b = Math.min(255, b * 1.8);
      }

      return `rgb(${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)})`;
    };

    const lines = buildOutput.split('\n');
    return lines.map((line, index) => {
      const anserOutput = Anser.ansiToJson(line, { use_classes: false });
      return (
        <div key={index}>
          {anserOutput.map((part, i) => {
            const style = {};
            if (part.fg) style.color = brightenColor(part.fg);
            if (part.bg) style.backgroundColor = `rgb(${part.bg})`;
            if (part.decoration) {
              if (part.decoration === 'bold') style.fontWeight = 'bold';
              if (part.decoration === 'italic') style.fontStyle = 'italic';
              if (part.decoration === 'underline') style.textDecoration = 'underline';
            }
            return (
              <span key={i} style={style}>
                {part.content}
              </span>
            );
          })}
        </div>
      );
    });
  }, [buildOutput]);

  // Auto-scroll terminal to bottom when new output arrives
  useEffect(() => {
    if (terminalOutputRef.current) {
      terminalOutputRef.current.scrollTop = terminalOutputRef.current.scrollHeight;
    }
  }, [buildOutput]);

  if (loading && template) {
    return (
      <div className="terraform-config">
        <div className="loading">Loading configuration schema...</div>
      </div>
    );
  }

  if (error && template) {
    return (
      <div className="terraform-config">
        <div className="error">
          <h2>Error Loading Schema</h2>
          <p>{error}</p>
          <button onClick={loadSchemaAndConfig}>Retry</button>
        </div>
      </div>
    );
  }

  return (
    <div className="terraform-config">
      <header className="config-header">
        <div className="header-content">
          <div className="header-branding">
            <img
              src="/fortinet-logo.svg"
              alt="Fortinet"
              className="fortinet-logo"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
            <h1>Terraform Configuration</h1>
          </div>
        </div>
        <div className="template-selector">
          <label htmlFor="template">Template:</label>
          <select
            id="template"
            value={template}
            onChange={(e) => handleTemplateChange(e.target.value)}
          >
            {registeredTemplates.length === 0 && (
              <option value="">No templates registered</option>
            )}
            {registeredTemplates.map(t => (
              <option key={t.id} value={t.name}>{t.name}</option>
            ))}
          </select>
          {driftStatus && (
            <span
              className={`drift-indicator drift-${driftStatus}${driftStatus !== 'clean' ? ' drift-clickable' : ''}`}
              onClick={driftStatus !== 'clean' ? () => setShowDriftResolution(true) : undefined}
              title={driftStatus !== 'clean' ? 'Click to resolve drift' : ''}
            >
              {driftStatus === 'clean' ? 'Clean' : driftStatus === 'warning' ? 'Warning' : 'Drift Detected'}
            </span>
          )}
          <button
            className="btn-register-template"
            onClick={() => setShowRegistration(true)}
            title="Register a new template"
          >
            +
          </button>
          {selectedTemplateId && (
            <>
              <button
                className="btn-template-action btn-clear-clone"
                onClick={async () => {
                  if (!window.confirm('Clear the local git clone for this template?')) return;
                  try {
                    await api.templates.clearClone(selectedTemplateId);
                    setDriftStatus(null);
                  } catch (err) {
                    alert('Failed to clear clone: ' + err.message);
                  }
                }}
                title="Clear local git clone (keeps DB record)"
              >
                Clear Clone
              </button>
              <button
                className="btn-template-action btn-delete-template"
                onClick={async () => {
                  const tmpl = registeredTemplates.find(t => t.id === selectedTemplateId);
                  if (!window.confirm(`Delete template "${tmpl?.name}" from the database?`)) return;
                  try {
                    await api.templates.delete(selectedTemplateId);
                    await loadRegisteredTemplates();
                  } catch (err) {
                    alert('Failed to delete template: ' + err.message);
                  }
                }}
                title="Delete template from database and clear clone"
              >
                Delete
              </button>
            </>
          )}
        </div>
        {selectedTemplateId && (() => {
          const tmpl = registeredTemplates.find(t => t.id === selectedTemplateId);
          if (!tmpl) return null;
          return (
            <div className="template-meta">
              <span className="meta-item">
                <strong>Repo:</strong> {tmpl.repo_url}
              </span>
              <span className="meta-item">
                <strong>Branch:</strong> {tmpl.branch}
              </span>
              <span className="meta-item">
                <strong>Last updated:</strong> {new Date(tmpl.updated_at).toLocaleDateString()}
              </span>
            </div>
          );
        })()}
        {!template.startsWith('gcp/') && !awsCredentialsValid && (
          <div className="warning">
            Warning: AWS credentials not detected. Some dropdowns may not populate.
          </div>
        )}
        {template.startsWith('gcp/') && !gcpCredentialsValid && (
          <div className="warning">
            Warning: GCP credentials not detected. Some dropdowns may not populate.
          </div>
        )}
      </header>

      {driftStatus === 'warning' && !driftDismissed && driftEntries.length > 0 && (
        <div className="drift-warning-banner">
          <div className="drift-warning-content">
            <strong>Drift detected:</strong> The following template files have changed since last snapshot:
            <ul className="drift-warning-files">
              {driftEntries.map((entry, i) => (
                <li key={i}>
                  <span className={`drift-warning-type drift-warning-${entry.drift_type}`}>
                    {entry.drift_type === 'changed' ? 'M' : entry.drift_type === 'added' ? 'A' : 'D'}
                  </span>
                  {entry.filename}
                </li>
              ))}
            </ul>
            <span className="drift-warning-note">This does not block plan/apply.</span>
          </div>
          <button
            className="drift-warning-dismiss"
            onClick={() => setDriftDismissed(true)}
            title="Dismiss"
          >
            &times;
          </button>
        </div>
      )}

      <main className="config-main">
        {schema && schema.groups.map(group => (
          <FormGroup
            key={group.name}
            group={group}
            config={config}
            onFieldChange={handleFieldChange}
            awsCredentialsValid={awsCredentialsValid}
            gcpCredentialsValid={gcpCredentialsValid}
            template={template}
            templateId={selectedTemplateId}
            inheritedFields={inheritedFields}
            derivedFields={derivedFields}
          />
        ))}
      </main>

      <footer className="config-footer">
        <div className="button-group">
          {hasSavedConfig && (
            <button
              className="btn btn-danger"
              onClick={handleReset}
            >
              Reset to Defaults
            </button>
          )}
          <button
            className="btn btn-secondary"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? 'Saving...' : 'Save Configuration'}
          </button>
          <button
            className="btn btn-primary"
            onClick={handleGenerate}
            disabled={generating}
          >
            {generating ? 'Generating...' : 'Generate terraform.tfvars'}
          </button>
          <button
            className="btn btn-success"
            onClick={handleBuild}
            disabled={building}
          >
            {building ? 'Building...' : 'Build Infrastructure (All Steps)'}
          </button>
          <button
            className="btn btn-danger"
            onClick={() => handleBuildStep('destroy')}
            disabled={building}
          >
            {building ? 'Destroying...' : 'Destroy Infrastructure'}
          </button>
          <button
            className="btn btn-secondary"
            onClick={() => setShowBuildSteps(!showBuildSteps)}
          >
            {showBuildSteps ? 'Hide Steps' : 'Show Individual Steps'}
          </button>
        </div>

        {showBuildSteps && (
          <div className="build-steps">
            <h4>Run Individual Steps:</h4>
            <div className="button-group">
              <button
                className="btn btn-primary"
                onClick={() => handleBuildStep('init')}
                disabled={building}
              >
                1. Init
              </button>
              <button
                className="btn btn-primary"
                onClick={() => handleBuildStep('plan')}
                disabled={building}
              >
                2. Plan
              </button>
              <button
                className="btn btn-success"
                onClick={() => handleBuildStep('apply')}
                disabled={building}
              >
                3. Apply
              </button>
              <button
                className="btn btn-danger"
                onClick={() => handleBuildStep('destroy')}
                disabled={building}
              >
                Destroy
              </button>
            </div>
          </div>
        )}

        {generatedContent && (
          <div className="generated-content">
            <h3>Generated terraform.tfvars</h3>
            <pre>{generatedContent.content}</pre>
            <div className="button-group">
              <button
                className="btn btn-primary"
                onClick={handleSaveToTemplate}
                disabled={savingToTemplate}
              >
                {savingToTemplate ? 'Saving...' : 'Save to Template Directory'}
              </button>
              <button
                className="btn btn-success"
                onClick={handleDownload}
              >
                Download {generatedContent.filename}
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleClear}
              >
                Clear
              </button>
            </div>
          </div>
        )}
      </footer>

      {showBuildTerminal && (
        <div className="build-terminal-overlay">
          <div className="build-terminal">
            <div className="terminal-header">
              <h3>Build Output</h3>
              <div className="terminal-buttons">
                <button
                  className="btn btn-primary"
                  onClick={handleSaveLog}
                  disabled={building || !buildOutput}
                >
                  Save Log
                </button>
                <button
                  className="btn btn-secondary terminal-close-btn"
                  onClick={handleCloseBuildTerminal}
                  disabled={building}
                >
                  {building ? 'Building...' : 'Close'}
                </button>
              </div>
            </div>
            <div className="terminal-output" ref={terminalOutputRef}>
              <pre>{colorizedOutput}</pre>
            </div>
          </div>
        </div>
      )}

      {showSaveLogModal && (
        <div className="modal-overlay">
          <div className="modal-dialog">
            <h3>Save Log to logs/verify_all.md</h3>
            <p>How would you like to save the log?</p>
            <div className="modal-buttons">
              <button
                className="btn btn-primary"
                onClick={() => handleSaveLogConfirm('append')}
              >
                Append
              </button>
              <button
                className="btn btn-warning"
                onClick={() => handleSaveLogConfirm('truncate')}
              >
                Overwrite
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => setShowSaveLogModal(false)}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      <TemplateRegistration
        isOpen={showRegistration}
        onClose={() => setShowRegistration(false)}
        onTemplateCreated={loadRegisteredTemplates}
      />

      <DriftResolution
        isOpen={showDriftResolution}
        templateId={selectedTemplateId}
        templateName={template}
        onClose={() => setShowDriftResolution(false)}
        onResolved={() => {
          checkDriftStatus(selectedTemplateId);
          loadRegisteredTemplates();
        }}
      />
    </div>
  );
}

export default TerraformConfig;
