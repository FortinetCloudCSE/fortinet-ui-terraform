import React, { useState, useEffect, useRef, useMemo } from 'react';
import api from '../services/api';
import FormGroup from './FormGroup';
import './TerraformConfig.css';
import Anser from 'anser';

function TerraformConfig() {
  const [template, setTemplate] = useState('existing_vpc_resources');
  const [schema, setSchema] = useState(null);
  const [config, setConfig] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [awsCredentialsValid, setAwsCredentialsValid] = useState(false);
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
  const [showSaveLogModal, setShowSaveLogModal] = useState(false);
  const terminalOutputRef = useRef(null);

  // Load schema and config on mount or template change
  useEffect(() => {
    loadSchemaAndConfig();
    checkAwsCredentials();
  }, [template]);

  const checkAwsCredentials = async () => {
    try {
      const status = await api.aws.checkCredentials();
      setAwsCredentialsValid(status.valid);
    } catch (err) {
      console.warn('AWS credentials not available:', err);
      setAwsCredentialsValid(false);
    }
  };

  const loadSchemaAndConfig = async () => {
    setLoading(true);
    setError(null);

    try {
      // Load schema
      const schemaData = await api.terraform.getSchema(template);
      setSchema(schemaData);

      // Try to load saved config
      const configData = await api.terraform.loadConfig(template);
      if (configData.success && configData.config) {
        setConfig(configData.config);
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
        setConfig({ ...defaults, ...configData.config });
        setHasSavedConfig(false);
        setInheritedFields(configData.inherited_fields || []);
      }
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

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.terraform.saveConfig(template, config);
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
      const result = await api.terraform.generateTfvars(template, config);
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
      const result = await api.terraform.saveToTemplate(template, config);
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

  if (loading) {
    return (
      <div className="terraform-config">
        <div className="loading">Loading configuration schema...</div>
      </div>
    );
  }

  if (error) {
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
            onChange={(e) => setTemplate(e.target.value)}
          >
            <option value="existing_vpc_resources">Existing VPC Resources</option>
            <option value="autoscale_template">AutoScale Template</option>
            <option value="ha_pair">HA Pair</option>
          </select>
        </div>
        {!awsCredentialsValid && (
          <div className="warning">
            Warning: AWS credentials not detected. Some dropdowns may not populate.
          </div>
        )}
      </header>

      <main className="config-main">
        {schema && schema.groups.map(group => (
          <FormGroup
            key={group.name}
            group={group}
            config={config}
            onFieldChange={handleFieldChange}
            awsCredentialsValid={awsCredentialsValid}
            template={template}
            inheritedFields={inheritedFields}
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
              {template === 'existing_vpc_resources' && (
                <>
                  <button
                    className="btn btn-primary"
                    onClick={() => handleBuildStep('verify_data')}
                    disabled={building}
                  >
                    4. Generate Verification
                  </button>
                  <button
                    className="btn btn-primary"
                    onClick={() => handleBuildStep('verify_all')}
                    disabled={building}
                  >
                    5. Verify All
                  </button>
                </>
              )}
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
    </div>
  );
}

export default TerraformConfig;
