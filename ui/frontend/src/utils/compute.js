/**
 * Compute field values from expressions
 * Supports Terraform-like functions for calculating network subnets
 */

/**
 * Parse and evaluate a compute expression
 * @param {string} expression - The expression to evaluate (e.g., "cidrsubnet(vpc_cidr, subnet_bits, 0)")
 * @param {object} config - Configuration object with field values
 * @returns {string} - Computed value
 */
export function computeValue(expression, config) {
  if (!expression) return '';

  try {
    // Match cidrsubnet function: cidrsubnet(vpc_var, bits_var, index)
    const cidrsubnetMatch = expression.match(/cidrsubnet\(([^,]+),\s*([^,]+),\s*(\d+)\)/);

    if (cidrsubnetMatch) {
      const [, vpcVarName, bitsVarName, indexStr] = cidrsubnetMatch;
      const vpcCidr = config[vpcVarName.trim()];
      const subnetBits = config[bitsVarName.trim()];
      const index = parseInt(indexStr, 10);

      if (!vpcCidr || !subnetBits) {
        return '';
      }

      return cidrsubnet(vpcCidr, subnetBits, index);
    }

    // Match template string: template("${var1}-${var2}-suffix")
    const templateMatch = expression.match(/template\("(.+)"\)/);

    if (templateMatch) {
      const template = templateMatch[1];
      return evaluateTemplate(template, config);
    }

    return '';
  } catch (err) {
    console.error('Error computing value:', expression, err);
    return '';
  }
}

/**
 * Evaluate a template string with variable substitution
 * @param {string} template - Template string with ${var} placeholders
 * @param {object} config - Configuration object with field values
 * @returns {string} - Evaluated string
 */
function evaluateTemplate(template, config) {
  return template.replace(/\$\{([^}]+)\}/g, (match, varName) => {
    const value = config[varName.trim()];
    return value !== undefined && value !== null && value !== '' ? value : match;
  });
}

/**
 * Calculate a subnet CIDR from a parent CIDR
 * Mimics Terraform's cidrsubnet function
 *
 * @param {string} ipRange - Parent CIDR (e.g., "10.0.0.0/16")
 * @param {number} newBits - Additional bits for subnet mask
 * @param {number} netNum - Network number (index)
 * @returns {string} - Calculated subnet CIDR
 */
function cidrsubnet(ipRange, newBits, netNum) {
  try {
    const [ip, prefixStr] = ipRange.split('/');
    const prefix = parseInt(prefixStr, 10);
    const newPrefix = prefix + newBits;

    if (newPrefix > 32) {
      throw new Error('Subnet prefix cannot exceed /32');
    }

    // Convert IP to integer
    const ipParts = ip.split('.').map(n => parseInt(n, 10));
    let ipInt = (ipParts[0] << 24) + (ipParts[1] << 16) + (ipParts[2] << 8) + ipParts[3];

    // Calculate the subnet
    const subnetSize = Math.pow(2, 32 - newPrefix);
    const subnetBase = (ipInt >> (32 - prefix)) << (32 - prefix);
    const subnetAddress = subnetBase + (netNum * subnetSize);

    // Convert back to dotted decimal
    const octet1 = (subnetAddress >>> 24) & 0xFF;
    const octet2 = (subnetAddress >>> 16) & 0xFF;
    const octet3 = (subnetAddress >>> 8) & 0xFF;
    const octet4 = subnetAddress & 0xFF;

    return `${octet1}.${octet2}.${octet3}.${octet4}/${newPrefix}`;
  } catch (err) {
    console.error('Error calculating subnet:', err);
    return '';
  }
}
