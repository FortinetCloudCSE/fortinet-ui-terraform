import React, { useState, useEffect } from 'react';
import api from '../services/api';
import './DriftResolution.css';

function DriftResolution({ isOpen, templateId, templateName, onClose, onResolved }) {
  const [driftReport, setDriftReport] = useState(null);
  const [currentContent, setCurrentContent] = useState('');
  const [editedContent, setEditedContent] = useState('');
  const [scaffoldContent, setScaffoldContent] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [scaffolding, setScaffolding] = useState(false);
  const [error, setError] = useState(null);
  const [showScaffold, setShowScaffold] = useState(false);

  useEffect(() => {
    if (isOpen && templateId) {
      loadDriftData();
    }
  }, [isOpen, templateId]);

  const loadDriftData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [drift, exported] = await Promise.all([
        api.templates.getDrift(templateId),
        api.templates.export(templateId),
      ]);
      setDriftReport(drift);
      setCurrentContent(exported.content || '');
      setEditedContent(exported.content || '');
      setScaffoldContent(null);
      setShowScaffold(false);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleReScaffold = async () => {
    setScaffolding(true);
    setError(null);
    try {
      const result = await api.templates.scaffold(templateId);
      setScaffoldContent(result.scaffold);
      setShowScaffold(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setScaffolding(false);
    }
  };

  const handleUseScaffold = () => {
    setEditedContent(scaffoldContent);
    setShowScaffold(false);
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await api.templates.import(templateId, editedContent);
      onResolved();
      onClose();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen) return null;

  const driftTypeIcon = (type) => {
    switch (type) {
      case 'changed': return 'M';
      case 'added': return 'A';
      case 'removed': return 'D';
      default: return '?';
    }
  };

  const driftTypeClass = (type) => {
    switch (type) {
      case 'changed': return 'drift-file-changed';
      case 'added': return 'drift-file-added';
      case 'removed': return 'drift-file-removed';
      default: return '';
    }
  };

  return (
    <div className="drift-overlay">
      <div className="drift-modal">
        <div className="drift-header">
          <h2>Drift Resolution — {templateName}</h2>
          <button className="drift-close" onClick={onClose}>&times;</button>
        </div>

        {error && <div className="drift-error">{error}</div>}

        {loading ? (
          <div className="drift-loading">Loading drift data...</div>
        ) : (
          <div className="drift-body">
            {/* Left panel: drift entries */}
            <div className="drift-entries-panel">
              <h3>Changed Files</h3>
              {driftReport && driftReport.entries.length > 0 ? (
                <ul className="drift-file-list">
                  {driftReport.entries.map((entry, i) => (
                    <li key={i} className={driftTypeClass(entry.drift_type)}>
                      <span className="drift-file-icon">
                        {driftTypeIcon(entry.drift_type)}
                      </span>
                      <span className="drift-file-name">{entry.filename}</span>
                      {entry.hard_stop && (
                        <span className="drift-hard-stop-badge">hard-stop</span>
                      )}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="drift-clean-msg">No drift detected.</p>
              )}

              <div className="drift-legend">
                <div className="drift-legend-item drift-file-added">
                  <span className="drift-file-icon">A</span> Added
                </div>
                <div className="drift-legend-item drift-file-changed">
                  <span className="drift-file-icon">M</span> Modified
                </div>
                <div className="drift-legend-item drift-file-removed">
                  <span className="drift-file-icon">D</span> Removed
                </div>
              </div>

              {driftReport && driftReport.status === 'hard_stop' && (
                <div className="drift-hard-stop-notice">
                  Hard-stop drift detected. Template files critical to the UI
                  (variables.tf, terraform.tfvars.example) have changed. Update
                  the tfvars.ui content to match.
                </div>
              )}
            </div>

            {/* Right panel: editor */}
            <div className="drift-editor-panel">
              <div className="drift-editor-toolbar">
                <h3>tfvars.ui Content</h3>
                <button
                  className="btn btn-primary"
                  onClick={handleReScaffold}
                  disabled={scaffolding}
                >
                  {scaffolding ? 'Scaffolding...' : 'Re-scaffold'}
                </button>
              </div>

              {showScaffold && scaffoldContent && (
                <div className="drift-scaffold-preview">
                  <div className="drift-scaffold-header">
                    <span>New scaffold preview</span>
                    <div className="drift-scaffold-actions">
                      <button
                        className="btn btn-success btn-sm"
                        onClick={handleUseScaffold}
                      >
                        Use This
                      </button>
                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => setShowScaffold(false)}
                      >
                        Dismiss
                      </button>
                    </div>
                  </div>
                  <pre className="drift-scaffold-content">{scaffoldContent}</pre>
                </div>
              )}

              <textarea
                className="drift-editor"
                value={editedContent}
                onChange={(e) => setEditedContent(e.target.value)}
                spellCheck={false}
              />
            </div>
          </div>
        )}

        <div className="drift-actions">
          <button className="btn btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn-success"
            onClick={handleSave}
            disabled={saving || loading}
          >
            {saving ? 'Saving...' : 'Save & Re-hash'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default DriftResolution;
