import React, { useState, useRef } from 'react';
import api from '../services/api';
import './TemplateRegistration.css';

function TemplateRegistration({ isOpen, onClose, onTemplateCreated }) {
  const [step, setStep] = useState('form'); // 'form' | 'scaffold'
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
  const fileInputRef = useRef(null);

  const resetState = () => {
    setStep('form');
    setFormData({ name: '', repo_url: '', branch: 'main', repo_path: '' });
    setLoading(false);
    setError(null);
    setTemplateId(null);
    setScaffoldContent('');
    setVariableCount(0);
  };

  const handleClose = () => {
    resetState();
    onClose();
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const template = await api.templates.create(formData);
      setTemplateId(template.id);

      // Auto-scaffold after registration
      const result = await api.templates.scaffold(template.id);
      setScaffoldContent(result.scaffold);
      setVariableCount(result.variable_count);
      setStep('scaffold');
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

  const handleDone = () => {
    onTemplateCreated();
    handleClose();
  };

  if (!isOpen) return null;

  return (
    <div className="reg-overlay">
      <div className="reg-modal">
        <div className="reg-header">
          <h2>
            {step === 'form' && 'Register Template'}
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
                placeholder="e.g., aws/existing_vpc_resources"
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
                  placeholder="terraform/aws/existing_vpc_resources"
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

        {step === 'scaffold' && (
          <div className="reg-scaffold">
            <div className="reg-scaffold-info">
              <p>
                Generated scaffold with <strong>{variableCount}</strong> variables
                from <strong>{formData.name}</strong>
              </p>
              <p className="reg-scaffold-hint">
                Export the scaffold, enrich it with UI annotations, then import it back.
              </p>
            </div>

            <pre className="reg-scaffold-content">{scaffoldContent}</pre>

            <input
              ref={fileInputRef}
              type="file"
              accept=".ui,.txt,.tfvars"
              onChange={handleFileUpload}
              style={{ display: 'none' }}
            />

            <div className="reg-actions">
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
              <button className="btn btn-success" onClick={handleDone}>
                Done
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default TemplateRegistration;
