import React, { useState, useRef, useEffect, useCallback } from 'react';
import api from '../services/api';
import './TemplateRegistration.css';

function TemplateRegistration({ isOpen, onClose, onTemplateCreated }) {
  const [step, setStep] = useState('form'); // 'form' | 'choose' | 'scaffold'
  const [formData, setFormData] = useState({
    name: '',
    repo_url: '',
    branch: 'main',
    repo_path: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [templateId, setTemplateId] = useState(null);
  const [scaffoldContent, setScaffoldContent] = useState('');
  const [variableCount, setVariableCount] = useState(0);
  const [scaffoldSource, setScaffoldSource] = useState(null);
  const [annotationCount, setAnnotationCount] = useState(0);
  const [conflictData, setConflictData] = useState(null);
  const [showPreview, setShowPreview] = useState(false);
  const [previewSchema, setPreviewSchema] = useState(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const fileInputRef = useRef(null);
  const debounceRef = useRef(null);

  const resetState = () => {
    setStep('form');
    setFormData({ name: '', repo_url: '', branch: 'main', repo_path: '' });
    setLoading(false);
    setError(null);
    setTemplateId(null);
    setScaffoldContent('');
    setVariableCount(0);
    setScaffoldSource(null);
    setAnnotationCount(0);
    setConflictData(null);
    setShowPreview(false);
    setPreviewSchema(null);
  };

  const handleClose = () => {
    resetState();
    onClose();
  };

  // Debounced preview fetch
  const fetchPreview = useCallback((content) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      if (!content.trim()) {
        setPreviewSchema(null);
        return;
      }
      setPreviewLoading(true);
      try {
        const result = await api.templates.previewSchema(content);
        setPreviewSchema(result);
      } catch (err) {
        console.warn('Preview parse error:', err);
      } finally {
        setPreviewLoading(false);
      }
    }, 400);
  }, []);

  // Fetch preview when content changes and preview is visible
  useEffect(() => {
    if (showPreview && scaffoldContent) {
      fetchPreview(scaffoldContent);
    }
  }, [showPreview, scaffoldContent, fetchPreview]);

  // Cleanup debounce on unmount
  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const template = await api.templates.create(formData);
      setTemplateId(template.id);

      // Auto-scaffold after registration
      const result = await api.templates.scaffold(template.id);

      if (result.conflict) {
        setConflictData(result);
        setStep('choose');
      } else {
        setScaffoldContent(result.scaffold);
        setVariableCount(result.variable_count);
        setScaffoldSource(result.source || 'generated');
        setAnnotationCount(result.annotation_count || 0);
        setStep('scaffold');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleExport = () => {
    const blob = new Blob([scaffoldContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${formData.name.replace(/\//g, '_')}.tfvars.ui`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const content = await file.text();
    setLoading(true);
    setError(null);

    try {
      await api.templates.import(templateId, content);
      setScaffoldContent(content);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
      e.target.value = '';
    }
  };

  const handleResolve = async (choice) => {
    setLoading(true);
    setError(null);
    try {
      const result = await api.templates.resolveScaffold(templateId, choice);
      setScaffoldContent(result.scaffold);
      setVariableCount(result.variable_count);
      setScaffoldSource(result.source);
      setConflictData(null);
      setStep('scaffold');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveAndDone = async () => {
    // Save current editor content to DB before closing
    setLoading(true);
    try {
      await api.templates.import(templateId, scaffoldContent);
    } catch (err) {
      // Non-fatal — content was already saved on scaffold/import
      console.warn('Save on done failed:', err);
    } finally {
      setLoading(false);
    }
    onTemplateCreated();
    handleClose();
  };

  if (!isOpen) return null;

  const isWide = step === 'choose' || (step === 'scaffold' && showPreview);

  return (
    <div className="reg-overlay">
      <div className={`reg-modal${isWide ? ' reg-modal-wide' : ''}`}>
        <div className="reg-header">
          <h2>
            {step === 'form' && 'Register Template'}
            {step === 'choose' && 'Existing Annotations Found'}
            {step === 'scaffold' && 'Review Scaffold'}
          </h2>
          <button className="reg-close" onClick={handleClose}>&times;</button>
        </div>

        {error && <div className="reg-error">{error}</div>}

        {step === 'form' && (
          <form onSubmit={handleRegister} className="reg-form">
            <div className="reg-field">
              <label htmlFor="reg-name">Template Name</label>
              <input
                id="reg-name"
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="e.g., my-fortigate-autoscale"
                required
              />
              <span className="reg-hint">Path-style identifier used in the template selector</span>
            </div>

            <div className="reg-field">
              <label htmlFor="reg-repo">Repository URL</label>
              <input
                id="reg-repo"
                type="url"
                value={formData.repo_url}
                onChange={(e) => setFormData({ ...formData, repo_url: e.target.value })}
                placeholder="https://github.com/org/repo.git"
                required
              />
            </div>

            <div className="reg-row">
              <div className="reg-field">
                <label htmlFor="reg-branch">Branch</label>
                <input
                  id="reg-branch"
                  type="text"
                  value={formData.branch}
                  onChange={(e) => setFormData({ ...formData, branch: e.target.value })}
                  placeholder="main"
                />
              </div>

              <div className="reg-field">
                <label htmlFor="reg-path">Path in Repo</label>
                <input
                  id="reg-path"
                  type="text"
                  value={formData.repo_path}
                  onChange={(e) => setFormData({ ...formData, repo_path: e.target.value })}
                  placeholder="path/to/template"
                />
                <span className="reg-hint">Path to the template directory within the repo</span>
              </div>
            </div>

            <div className="reg-actions">
              <button type="button" className="btn btn-secondary" onClick={handleClose}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={loading}>
                {loading ? 'Registering...' : 'Register & Scaffold'}
              </button>
            </div>
          </form>
        )}

        {step === 'choose' && conflictData && (
          <div className="reg-scaffold">
            <div className="reg-scaffold-info">
              <p>
                Both the <strong>repository</strong> and the <strong>database</strong> have
                a tfvars.ui for <strong>{formData.name}</strong>.
              </p>
              <p className="reg-scaffold-hint">
                Which version would you like to use?
              </p>
            </div>

            <div className="reg-choose-options">
              <div className="reg-choose-option">
                <h3>Repository ({conflictData.repo_variable_count} variables)</h3>
                <pre className="reg-scaffold-content reg-choose-preview">{conflictData.repo_scaffold}</pre>
                <button
                  className="btn btn-primary"
                  onClick={() => handleResolve('repo')}
                  disabled={loading}
                >
                  {loading ? 'Loading...' : 'Use Repository'}
                </button>
              </div>
              <div className="reg-choose-option">
                <h3>Database ({conflictData.db_variable_count} variables)</h3>
                <pre className="reg-scaffold-content reg-choose-preview">{conflictData.db_scaffold}</pre>
                <button
                  className="btn btn-primary"
                  onClick={() => handleResolve('db')}
                  disabled={loading}
                >
                  {loading ? 'Loading...' : 'Keep Database'}
                </button>
              </div>
            </div>
          </div>
        )}

        {step === 'scaffold' && (
          <div className="reg-scaffold">
            <div className="reg-scaffold-info">
              {(scaffoldSource === 'existing_tfvars_ui' || scaffoldSource === 'repo') && (
                <p>
                  Using <strong>tfvars.ui</strong> from repository with{' '}
                  <strong>{variableCount}</strong> variables
                </p>
              )}
              {scaffoldSource === 'db' && (
                <p>
                  Keeping <strong>database</strong> version with{' '}
                  <strong>{variableCount}</strong> variables
                </p>
              )}
              {scaffoldSource === 'annotated_example' && (
                <p>
                  Preserved <strong>{annotationCount}</strong> @ui- annotations
                  across <strong>{variableCount}</strong> variables
                </p>
              )}
              {scaffoldSource === 'generated' && (
                <p>
                  Generated scaffold with <strong>{variableCount}</strong> variables
                </p>
              )}
            </div>

            <div className={`reg-editor-area${showPreview ? ' reg-editor-split' : ''}`}>
              <div className="reg-editor-pane">
                <textarea
                  className="reg-scaffold-editor"
                  value={scaffoldContent}
                  onChange={(e) => setScaffoldContent(e.target.value)}
                  spellCheck={false}
                />
              </div>
              {showPreview && (
                <div className="reg-preview-pane">
                  {previewLoading && <div className="reg-preview-loading">Parsing...</div>}
                  {previewSchema && previewSchema.groups && (
                    <div className="reg-preview-form">
                      {previewSchema.groups.map((group) => (
                        <div key={group.name} className="reg-preview-group">
                          <h4 className="reg-preview-group-title">{group.label}</h4>
                          <div className="reg-preview-fields">
                            {group.fields.map((field) => (
                              <PreviewField key={field.name} field={field} />
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                  {!previewLoading && (!previewSchema || !previewSchema.groups?.length) && (
                    <div className="reg-preview-empty">No fields to preview</div>
                  )}
                </div>
              )}
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept=".ui,.txt,.tfvars"
              onChange={handleFileUpload}
              style={{ display: 'none' }}
            />

            <div className="reg-actions">
              <button
                className={`btn ${showPreview ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setShowPreview(!showPreview)}
              >
                {showPreview ? 'Hide Preview' : 'Preview'}
              </button>
              <button className="btn btn-secondary" onClick={handleExport}>
                Export
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleImportClick}
                disabled={loading}
              >
                {loading ? 'Importing...' : 'Import'}
              </button>
              <button className="btn btn-success" onClick={handleSaveAndDone}>
                Save & Done
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}


/**
 * Renders a single field preview — shows the label, type, and a non-functional
 * widget so the user can see what the form will look like.
 */
function PreviewField({ field }) {
  const width = field.width === 'half' ? 'half' : 'full';

  // Parse options for select fields
  const options = [];
  if (field.options) {
    field.options.split(',').forEach((opt) => {
      const trimmed = opt.trim();
      const [value, label] = trimmed.includes('|')
        ? trimmed.split('|', 2)
        : [trimmed, trimmed];
      options.push({ value, label });
    });
  }

  const showIf = field.show_if || field.hide_if;

  return (
    <div className={`reg-preview-field reg-preview-field-${width}`}>
      <label className="reg-preview-label">
        {field.label}
        {field.required && <span className="reg-preview-required">*</span>}
        {showIf && <span className="reg-preview-conditional" title={showIf}>?</span>}
      </label>
      {field.description && (
        <span className="reg-preview-description">{field.description}</span>
      )}
      <div className="reg-preview-widget">
        {field.type === 'checkbox' && (
          <input type="checkbox" checked={field.default_value === true} readOnly />
        )}
        {field.type === 'select' && (
          <select defaultValue={field.default_value || ''} disabled>
            <option value="">-- select --</option>
            {options.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
            {field.source && field.source !== 'static' && (
              <option disabled>[live: {field.source}]</option>
            )}
          </select>
        )}
        {field.type === 'password' && (
          <input type="password" placeholder={field.placeholder || ''} readOnly />
        )}
        {(field.type === 'text' || field.type === 'number' || !['checkbox', 'select', 'password'].includes(field.type)) && field.type !== 'checkbox' && field.type !== 'select' && field.type !== 'password' && (
          <input
            type={field.type === 'number' ? 'number' : 'text'}
            defaultValue={field.default_value ?? ''}
            placeholder={field.placeholder || ''}
            readOnly
          />
        )}
      </div>
    </div>
  );
}


export default TemplateRegistration;
