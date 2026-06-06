import React, { useState, useEffect, useMemo } from 'react';
import api from '../services/api';
import { evaluateCondition } from '../utils/conditions';
import { validateField } from '../utils/validation';
import { computeValue } from '../utils/compute';
import './FormField.css';

function FormField({ field, value, config, onChange, awsCredentialsValid, gcpCredentialsValid, template, templateId, isInherited }) {
  const [options, setOptions] = useState([]);
  const [loadingOptions, setLoadingOptions] = useState(false);
  const [validationError, setValidationError] = useState(null);
  const [licenseFiles, setLicenseFiles] = useState([]);
  const [uploadingLicense, setUploadingLicense] = useState(false);

  // Check if field should be visible
  const isVisible = useMemo(() => {
    if (field.show_if) {
      return evaluateCondition(field.show_if, config);
    }
    if (field.hide_if) {
      return !evaluateCondition(field.hide_if, config);
    }
    return true;
  }, [field.show_if, field.hide_if, config]);

  // Load options for select fields
  useEffect(() => {
    if (!isVisible || (field.type !== 'select' && field.type !== 'multiselect')) return;

    const loadOptions = async () => {
      setLoadingOptions(true);
      try {
        let optionsList = [];

        switch (field.source) {
          case 'aws-regions':
            if (awsCredentialsValid) {
              const regions = await api.aws.getRegions();
              optionsList = regions.map(r => ({ value: r.name, label: r.name }));
            }
            break;

          case 'aws-availability-zones':
            if (awsCredentialsValid && field.depends_on && config[field.depends_on]) {
              const region = config[field.depends_on];
              const azs = await api.aws.getAvailabilityZones(region);
              // Extract just the letter (last character)
              optionsList = azs.map(az => ({
                value: az.zone_name.slice(-1),
                label: `${az.zone_name.slice(-1)} (${az.zone_name})`
              }));
            }
            break;

          case 'aws-keypairs':
            if (awsCredentialsValid && config.aws_region) {
              const keypairs = await api.aws.getKeypairs(config.aws_region);
              optionsList = keypairs.map(kp => ({ value: kp.name, label: kp.name }));
            }
            break;

          case 'aws-vpcs':
            if (awsCredentialsValid && config.aws_region) {
              const vpcs = await api.aws.getVpcs(config.aws_region);
              optionsList = vpcs.map(vpc => ({
                value: vpc.id,
                label: `${vpc.name || vpc.id} (${vpc.cidr})`
              }));
            }
            break;

          case 'license-files':
            if (templateId) {
              const dir = field.file_directory || 'licenses';
              const files = await api.terraform.getLicenseFiles(templateId, dir);
              setLicenseFiles(files);
              optionsList = files;
            }
            break;

          case 'aws-fortinet-resource':
            // Tag-based resource discovery using Fortinet-Role tags
            // Requires: field.tag_pattern, field.tag_resource_type
            // Pattern placeholders: {cp}, {env}, {region}, {az1}, {az2}
            if (awsCredentialsValid && field.tag_pattern && field.tag_resource_type) {
              const tagKey = field.tag_key || 'Fortinet-Role';
              // Replace placeholders in tag pattern with config values
              let tagValue = field.tag_pattern
                .replace('{cp}', config.cp || '')
                .replace('{env}', config.env || '')
                .replace('{region}', config.aws_region || '')
                .replace('{az1}', config.availability_zone_1 || '')
                .replace('{az2}', config.availability_zone_2 || '');

              if (config.aws_region && config.cp && config.env) {
                const resource = await api.aws.discoverResourceByTag(
                  config.aws_region,
                  tagKey,
                  tagValue,
                  field.tag_resource_type
                );
                if (resource) {
                  optionsList = [{
                    value: resource.resource_id,
                    label: `${resource.name || resource.resource_id} (${tagValue})`
                  }];
                }
              }
            }
            break;

          case 'gcp-regions':
            if (gcpCredentialsValid && config.gcp_project) {
              const gcpRegions = await api.gcp.getRegions(config.gcp_project);
              optionsList = gcpRegions.map(r => ({ value: r.name, label: r.name }));
            }
            break;

          case 'gcp-zones':
            if (gcpCredentialsValid && config.gcp_project && field.depends_on && config[field.depends_on]) {
              const gcpRegion = config[field.depends_on];
              const gcpZones = await api.gcp.getZones(config.gcp_project, gcpRegion);
              optionsList = gcpZones.map(z => ({ value: z.name, label: z.name }));
            }
            break;

          case 'gcp-networks':
            if (gcpCredentialsValid && config.gcp_project) {
              const gcpNetworks = await api.gcp.getNetworks(config.gcp_project);
              optionsList = gcpNetworks.map(n => ({ value: n.name, label: n.name }));
            }
            break;

          case 'gcp-subnetworks':
            if (gcpCredentialsValid && config.gcp_project && config.gcp_region) {
              const gcpSubnets = await api.gcp.getSubnetworks(config.gcp_project, config.gcp_region);
              optionsList = gcpSubnets.map(s => ({ value: s.name, label: `${s.name} (${s.ip_cidr_range})` }));
            }
            break;

          case 'gcp-fortinet-resource':
            if (gcpCredentialsValid && config.gcp_project && field.label_pattern && field.label_resource_type) {
              const labelKey = field.label_key || 'fortinet-role';
              let labelValue = field.label_pattern
                .replace('{cp}', config.cp || '')
                .replace('{env}', config.env || '');
              if (config.gcp_project && config.cp && config.env) {
                const gcpResource = await api.gcp.discoverResourceByLabel(
                  config.gcp_project, labelKey, labelValue, field.label_resource_type
                );
                if (gcpResource) {
                  optionsList = [{
                    value: gcpResource.resource_id,
                    label: `${gcpResource.name || gcpResource.resource_id} (${labelValue})`
                  }];
                }
              }
            }
            break;

          case 'fortiflex-configs': {
            const flexUser = config.fortiflex_username;
            const flexPass = config.fortiflex_password;
            if (flexUser && flexPass) {
              const result = await api.fortiflex.getConfigs(flexUser, flexPass);
              optionsList = (result.configs || []).map(c => ({
                value: c.id,
                label: c.name ? `${c.id} — ${c.name}` : c.id,
              }));
            }
            break;
          }

          case 'fortiflex-serials': {
            const flexUser = config.fortiflex_username;
            const flexPass = config.fortiflex_password;
            const configIds = (Array.isArray(config.fortiflex_configid_list)
              ? config.fortiflex_configid_list
              : []
            ).filter(id => id && id !== '');
            if (flexUser && flexPass && configIds.length > 0) {
              const result = await api.fortiflex.getSerials(flexUser, flexPass, configIds);
              optionsList = (result.serials || []).map(sn => ({ value: sn, label: sn }));
            }
            break;
          }

          case 'static':
            if (field.options) {
              // Parse options format: "value1|Label 1,value2|Label 2"
              optionsList = field.options.split(',').map(opt => {
                const [value, label] = opt.split('|');
                return { value: value.trim(), label: label?.trim() || value.trim() };
              });
            }
            break;

          default:
            // If no source but options are defined, treat as static options
            if (field.options) {
              optionsList = field.options.split(',').map(opt => {
                const [value, label] = opt.split('|');
                return { value: value.trim(), label: label?.trim() || value.trim() };
              });
            }
            break;
        }

        setOptions(optionsList);
      } catch (err) {
        console.error(`Error loading options for ${field.name}:`, err);
        setOptions([]);
      } finally {
        setLoadingOptions(false);
      }
    };

    loadOptions();
  }, [field, config, awsCredentialsValid, gcpCredentialsValid, isVisible, templateId]);

  // Compute value for output fields
  const computedValue = useMemo(() => {
    if (field.type === 'output' && field.compute) {
      return computeValue(field.compute, config);
    }
    return null;
  }, [field.type, field.compute, config]);

  // Validate on value change
  useEffect(() => {
    if (value !== undefined && value !== null && value !== '') {
      const error = validateField(field, value, config);
      setValidationError(error);
    } else {
      setValidationError(null);
    }
  }, [value, field, config]);

  const handleChange = (e) => {
    let newValue;

    switch (field.type) {
      case 'boolean':
      case 'checkbox':
        newValue = e.target.checked;
        break;
      case 'number':
        newValue = e.target.value === '' ? '' : Number(e.target.value);
        break;
      default:
        newValue = e.target.value;
    }

    onChange(newValue);
  };

  // License file helpers
  const refreshLicenseFiles = async () => {
    if (!templateId) return;
    const dir = field.file_directory || 'licenses';
    try {
      const files = await api.templates.listLicenseFiles(templateId, dir);
      setLicenseFiles(files);
      setOptions(files);
    } catch (err) {
      console.error('Failed to refresh license files:', err);
    }
  };

  const handleLicenseUpload = async (e) => {
    const files = e.target.files;
    if (!files || files.length === 0 || !templateId) return;
    const dir = field.file_directory || 'licenses';
    setUploadingLicense(true);
    try {
      for (const file of files) {
        await api.templates.uploadLicenseFile(templateId, file, dir);
      }
      await refreshLicenseFiles();
    } catch (err) {
      console.error('License upload failed:', err);
      alert(`Upload failed: ${err.message}`);
    } finally {
      setUploadingLicense(false);
      e.target.value = '';
    }
  };

  const handleLicenseDelete = async (filename) => {
    if (!templateId) return;
    const dir = field.file_directory || 'licenses';
    try {
      await api.templates.deleteLicenseFile(templateId, filename, dir);
      await refreshLicenseFiles();
      // Clear value if the deleted file was selected
      if (value === `./${dir}/${filename}`) {
        onChange('');
      }
    } catch (err) {
      console.error('License delete failed:', err);
      alert(`Delete failed: ${err.message}`);
    }
  };

  if (!isVisible) {
    return null;
  }

  const widthClass = field.width === 'half' ? 'field-half' : 'field-full';
  const requiredClass = field.required ? 'field-required' : '';
  const errorClass = validationError ? 'field-error' : '';

  return (
    <div className={`form-field ${widthClass} ${requiredClass} ${errorClass}`}>
      <label htmlFor={field.name}>
        {field.label || field.name}
        {field.required && <span className="required-indicator">*</span>}
      </label>

      {field.description && (
        <p className="field-description">{field.description}</p>
      )}

      {renderInput()}

      {field.help && (
        <p className="field-help">{field.help}</p>
      )}

      {validationError && (
        <p className="field-validation-error">{validationError}</p>
      )}
    </div>
  );

  function renderInput() {
    switch (field.type) {
      case 'text':
      case 'password':
        return (
          <input
            type={field.type}
            id={field.name}
            name={field.name}
            value={value || ''}
            onChange={handleChange}
            placeholder={field.placeholder}
            pattern={field.pattern}
            required={field.required}
            disabled={isInherited}
            title={isInherited ? "This value is inherited from existing_vpc_resources and cannot be changed" : ""}
          />
        );

      case 'number':
        return (
          <input
            type="number"
            id={field.name}
            name={field.name}
            value={value ?? ''}
            onChange={handleChange}
            placeholder={field.placeholder}
            required={field.required}
          />
        );

      case 'slider':
      case 'range': {
        // Extract min/max from validation rules (validation is an array)
        const validationStr = Array.isArray(field.validation) ? field.validation.join(',') : (field.validation || '');
        const sliderMin = validationStr.match(/min:(\d+)/)?.[1] || 0;
        const sliderMax = validationStr.match(/max:(\d+)/)?.[1] || 100;
        return (
          <div className="slider-wrapper">
            <input
              type="range"
              id={field.name}
              name={field.name}
              value={value ?? field.default_value ?? sliderMin}
              onChange={handleChange}
              min={sliderMin}
              max={sliderMax}
              required={field.required}
            />
            <span className="slider-value">{value ?? field.default_value ?? sliderMin}</span>
          </div>
        );
      }

      case 'boolean':
      case 'checkbox':
        return (
          <div className="checkbox-wrapper">
            <input
              type="checkbox"
              id={field.name}
              name={field.name}
              checked={value || false}
              onChange={handleChange}
              disabled={isInherited}
              title={isInherited ? "This value is inherited from existing_vpc_resources and cannot be changed" : ""}
            />
            <label htmlFor={field.name} className="checkbox-label">
              {field.label}
            </label>
          </div>
        );

      case 'select':
        if (field.source === 'license-files') {
          const isMulti = !!field.file_count;
          const selectedFiles = isMulti ? (Array.isArray(value) ? value : (value ? [value] : [])) : [];
          return (
            <div className="license-file-field">
              <div className="license-file-controls">
                {!isMulti ? (
                  <select
                    id={field.name}
                    name={field.name}
                    value={value || ''}
                    onChange={handleChange}
                    disabled={loadingOptions || uploadingLicense}
                    required={field.required}
                  >
                    <option value="">
                      {loadingOptions ? 'Loading...' : licenseFiles.length === 0 ? 'No license files — upload one' : 'Select a license file...'}
                    </option>
                    {licenseFiles.map(opt => (
                      <option key={opt.value} value={opt.value}>{opt.label}</option>
                    ))}
                  </select>
                ) : (
                  <div className="license-file-list">
                    {licenseFiles.length === 0 && !loadingOptions && (
                      <span className="license-file-empty">No license files — upload below</span>
                    )}
                    {licenseFiles.map(f => (
                      <div key={f.value} className="license-file-item">
                        <span className="license-file-name">{f.label}</span>
                        <button
                          type="button"
                          className="license-file-delete-btn"
                          onClick={() => handleLicenseDelete(f.label)}
                          title="Remove license file"
                        >
                          &times;
                        </button>
                      </div>
                    ))}
                  </div>
                )}
                <label className="license-upload-btn" title="Upload .lic file">
                  {uploadingLicense ? 'Uploading...' : 'Upload'}
                  <input
                    type="file"
                    accept=".lic"
                    multiple={isMulti}
                    onChange={handleLicenseUpload}
                    disabled={uploadingLicense || !templateId}
                    style={{ display: 'none' }}
                  />
                </label>
                {!isMulti && value && (
                  <button
                    type="button"
                    className="license-file-delete-btn"
                    onClick={() => {
                      const filename = licenseFiles.find(f => f.value === value)?.label;
                      if (filename) handleLicenseDelete(filename);
                    }}
                    title="Delete selected file"
                  >
                    &times;
                  </button>
                )}
              </div>
              {isMulti && field.file_count && (
                <span className="license-file-count">
                  {licenseFiles.length} of {field.file_count} licenses uploaded
                </span>
              )}
              {!templateId && (
                <span className="license-file-warning">Register a template to upload license files</span>
              )}
            </div>
          );
        }
        return (
          <select
            id={field.name}
            name={field.name}
            value={value || ''}
            onChange={handleChange}
            disabled={loadingOptions || isInherited}
            required={field.required}
            title={isInherited ? "This value is inherited from existing_vpc_resources and cannot be changed" : ""}
          >
            <option value="">
              {loadingOptions ? 'Loading...' : isInherited ? `Inherited: ${value}` : 'Select an option...'}
            </option>
            {options.map(opt => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        );

      case 'cidr':
        return (
          <input
            type="text"
            id={field.name}
            name={field.name}
            value={value || ''}
            onChange={handleChange}
            placeholder={field.placeholder || '10.0.0.0/16'}
            pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"
            required={field.required}
          />
        );

      case 'file':
        return (
          <input
            type="text"
            id={field.name}
            name={field.name}
            value={value || ''}
            onChange={handleChange}
            placeholder={field.placeholder || 'Path to file...'}
            required={field.required}
          />
        );

      case 'output':
        return (
          <input
            type="text"
            id={field.name}
            name={field.name}
            value={computedValue || ''}
            readOnly
            disabled
            className="output-field"
            placeholder={field.placeholder || 'Calculated value...'}
          />
        );

      case 'multiselect':
        return (
          <div>
            <select
              id={field.name}
              name={field.name}
              multiple
              size={Math.min(Math.max(options.length, 3), 8)}
              value={Array.isArray(value) ? value : []}
              onChange={(e) => {
                const selected = Array.from(e.target.selectedOptions, opt => opt.value);
                onChange(selected);
              }}
              disabled={loadingOptions}
              required={field.required}
              style={{ width: '100%' }}
            >
              {loadingOptions
                ? <option disabled>Loading...</option>
                : options.length === 0
                  ? <option disabled>No options available</option>
                  : options.map(opt => (
                      <option key={opt.value} value={opt.value}>{opt.label}</option>
                    ))
              }
            </select>
            {options.length > 0 && (
              <p className="field-help" style={{ marginTop: '4px' }}>
                Hold Ctrl/Cmd to select multiple
              </p>
            )}
          </div>
        );

      case 'list':
        return (
          <div className="list-field">
            {(Array.isArray(value) ? value : []).map((item, index) => (
              <div key={index} className="list-item">
                <input
                  type="text"
                  value={item}
                  onChange={(e) => {
                    const newList = [...(Array.isArray(value) ? value : [])];
                    newList[index] = e.target.value;
                    onChange(newList);
                  }}
                  placeholder={field.placeholder || 'Enter value...'}
                />
                <button
                  type="button"
                  onClick={() => {
                    const newList = (Array.isArray(value) ? value : []).filter((_, i) => i !== index);
                    onChange(newList);
                  }}
                  className="list-remove-btn"
                >
                  Remove
                </button>
              </div>
            ))}
            <button
              type="button"
              onClick={() => {
                const newList = [...(Array.isArray(value) ? value : []), ''];
                onChange(newList);
              }}
              className="list-add-btn"
            >
              + Add Item
            </button>
          </div>
        );

      default:
        return (
          <input
            type="text"
            id={field.name}
            name={field.name}
            value={value || ''}
            onChange={handleChange}
            placeholder={field.placeholder}
            required={field.required}
          />
        );
    }
  }
}

export default FormField;
