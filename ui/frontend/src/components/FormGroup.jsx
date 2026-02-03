import React, { useMemo } from 'react';
import FormField from './FormField';
import { evaluateCondition } from '../utils/conditions';
import './FormGroup.css';

function FormGroup({ group, config, onFieldChange, awsCredentialsValid, template, inheritedFields }) {
  // Check if group should be visible based on show_if condition
  const isVisible = useMemo(() => {
    if (!group.show_if) return true;
    return evaluateCondition(group.show_if, config);
  }, [group.show_if, config]);

  // Handle field change with exclusive checkbox logic
  const handleFieldChange = (fieldName, value, field) => {
    // Update the field
    onFieldChange(fieldName, value);

    // Handle exclusive checkboxes
    if (field.exclusive_with && value === true && (field.type === 'checkbox' || field.type === 'boolean')) {
      // If this checkbox is being checked and has an exclusive_with field,
      // uncheck the other field
      setTimeout(() => {
        onFieldChange(field.exclusive_with, false);
      }, 0);
    }
  };

  if (!isVisible) {
    return null;
  }

  return (
    <div className="form-group">
      <div className="group-header">
        <h2>{group.name}</h2>
        {group.description && (
          <p className="group-description">{group.description}</p>
        )}
      </div>

      <div className="group-fields">
        {group.fields.map(field => (
          <FormField
            key={field.name}
            field={field}
            value={config[field.name]}
            config={config}
            onChange={(value) => handleFieldChange(field.name, value, field)}
            awsCredentialsValid={awsCredentialsValid}
            template={template}
            isInherited={inheritedFields && inheritedFields.includes(field.name)}
          />
        ))}
      </div>
    </div>
  );
}

export default FormGroup;
