/**
 * Validate field values based on validation rules
 *
 * Supports validation rules like:
 * - min-length:N
 * - max-length:N
 * - min:N
 * - max:N
 * - gte:field_name (greater than or equal to another field's value)
 * - lte:field_name (less than or equal to another field's value)
 * - cidr
 * - version-format
 * - single-letter
 * - different-from:field_name
 * - within:field_name
 * - not-overlap:field_name
 */

export function validateField(field, value, config) {
  if (!field.validation || field.validation.length === 0) {
    return null; // No validation rules
  }

  for (const rule of field.validation) {
    const error = validateRule(rule, value, field, config);
    if (error) {
      return error; // Return first error found
    }
  }

  return null; // All validations passed
}

function validateRule(rule, value, field, config) {
  const ruleParts = rule.split(':');
  const ruleName = ruleParts[0];
  const ruleParam = ruleParts[1];

  switch (ruleName) {
    case 'min-length':
      if (String(value).length < parseInt(ruleParam)) {
        return `Minimum length is ${ruleParam} characters`;
      }
      break;

    case 'max-length':
      if (String(value).length > parseInt(ruleParam)) {
        return `Maximum length is ${ruleParam} characters`;
      }
      break;

    case 'min':
      if (Number(value) < Number(ruleParam)) {
        return `Minimum value is ${ruleParam}`;
      }
      break;

    case 'max':
      if (Number(value) > Number(ruleParam)) {
        return `Maximum value is ${ruleParam}`;
      }
      break;

    case 'gte':
      // Greater than or equal to another field's value
      if (config[ruleParam] !== undefined && config[ruleParam] !== null && config[ruleParam] !== '') {
        if (Number(value) < Number(config[ruleParam])) {
          return `Must be greater than or equal to ${ruleParam} (${config[ruleParam]})`;
        }
      }
      break;

    case 'lte':
      // Less than or equal to another field's value
      if (config[ruleParam] !== undefined && config[ruleParam] !== null && config[ruleParam] !== '') {
        if (Number(value) > Number(config[ruleParam])) {
          return `Must be less than or equal to ${ruleParam} (${config[ruleParam]})`;
        }
      }
      break;

    case 'cidr':
      if (!isValidCIDR(value)) {
        return 'Invalid CIDR format (e.g., 10.0.0.0/16)';
      }
      break;

    case 'version-format':
      if (!isValidVersion(value)) {
        return 'Invalid version format (use X.Y or X.Y.Z)';
      }
      break;

    case 'single-letter':
      if (!/^[a-z]$/i.test(value)) {
        return 'Must be a single letter (a-z)';
      }
      break;

    case 'different-from':
      if (value === config[ruleParam]) {
        return `Must be different from ${ruleParam}`;
      }
      break;

    case 'within':
      if (!isIPWithinCIDR(value, config[ruleParam])) {
        return `IP must be within ${ruleParam} CIDR range`;
      }
      break;

    case 'not-overlap':
      if (doCIDRsOverlap(value, config[ruleParam])) {
        return `CIDR must not overlap with ${ruleParam}`;
      }
      break;

    case 'required':
      if (value === null || value === undefined || value === '') {
        return 'This field is required';
      }
      break;

    default:
      console.warn(`Unknown validation rule: ${ruleName}`);
  }

  return null;
}

// Validation helper functions

function isValidCIDR(cidr) {
  if (!cidr) return false;
  const cidrRegex = /^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$/;
  if (!cidrRegex.test(cidr)) return false;

  // Validate IP octets are 0-255
  const [ip, mask] = cidr.split('/');
  const octets = ip.split('.');
  return octets.every(octet => {
    const num = parseInt(octet);
    return num >= 0 && num <= 255;
  });
}

function isValidVersion(version) {
  if (!version) return false;
  // Matches X.Y or X.Y.Z format
  return /^\d+\.\d+(\.\d+)?$/.test(String(version));
}

function ipToInt(ip) {
  const octets = ip.split('.').map(Number);
  return (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3];
}

function isIPWithinCIDR(ip, cidr) {
  if (!ip || !cidr) return false;

  try {
    const [cidrIP, maskBits] = cidr.split('/');
    const mask = ~((1 << (32 - parseInt(maskBits))) - 1);

    const ipInt = ipToInt(ip);
    const cidrInt = ipToInt(cidrIP);

    return (ipInt & mask) === (cidrInt & mask);
  } catch (err) {
    console.error('Error checking IP within CIDR:', err);
    return false;
  }
}

function doCIDRsOverlap(cidr1, cidr2) {
  if (!cidr1 || !cidr2) return false;

  try {
    const [ip1, mask1] = cidr1.split('/');
    const [ip2, mask2] = cidr2.split('/');

    const maskBits1 = parseInt(mask1);
    const maskBits2 = parseInt(mask2);

    // Use the smaller (more restrictive) mask
    const smallerMask = Math.min(maskBits1, maskBits2);
    const mask = ~((1 << (32 - smallerMask)) - 1);

    const int1 = ipToInt(ip1);
    const int2 = ipToInt(ip2);

    // If network addresses are the same after applying mask, they overlap
    return (int1 & mask) === (int2 & mask);
  } catch (err) {
    console.error('Error checking CIDR overlap:', err);
    return false;
  }
}
