import React, { useState, useEffect, useMemo } from 'react';
import api from '../services/api';
import { evaluateCondition } from '../utils/conditions';
import { validateField } from '../utils/validation';
import { computeValue } from '../utils/compute';
import './FormField.css';

function FormField({ field, value, config, onChange, awsCredentialsValid, template, isInherited }) {
  const [options, setOptions] = useState([]);
  const [loadingOptions, setLoadingOptions] = useState(false);
  const [validationError, setValidationError] = useState(null);

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
    if (!isVisible || field.type !== 'select') return;

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
            if (template) {
              const files = await api.terraform.getLicenseFiles(template);
              optionsList = files;
            }
            break;

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
  }, [field, config, awsCredentialsValid, isVisible]);

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
          <select
            id={field.name}
            name={field.name}
            multiple
            value={Array.isArray(value) ? value : []}
            onChange={(e) => {
              const selected = Array.from(e.target.selectedOptions, opt => opt.value);
              onChange(selected);
            }}
            disabled={loadingOptions}
            required={field.required}
          >
            {options.map(opt => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
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
