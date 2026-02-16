/**
 * API service for communicating with the FastAPI backend
 */

const API_BASE_URL = 'http://127.0.0.1:8000';

/**
 * Helper: find a registered template ID by name
 */
async function _findTemplateId(templateName) {
  const templates = await apiFetch('/api/templates');
  const match = templates.find(t => t.name === templateName);
  return match ? match.id : null;
}

/**
 * Helper: convert config object to terraform.tfvars content
 */
function _configToTfvars(config) {
  const lines = [];
  for (const [key, value] of Object.entries(config)) {
    if (value === undefined || value === null || value === '') continue;
    if (typeof value === 'boolean') {
      lines.push(`${key} = ${value}`);
    } else if (typeof value === 'number') {
      lines.push(`${key} = ${value}`);
    } else if (Array.isArray(value)) {
      const items = value.map(v => {
        if (typeof v === 'boolean') return v;
        if (typeof v === 'number') return v;
        const s = String(v);
        if (s.startsWith('"') && s.endsWith('"')) return s;
        return `"${s}"`;
      }).join(', ');
      lines.push(`${key} = [${items}]`);
    } else {
      lines.push(`${key} = "${value}"`);
    }
  }
  return lines.join('\n') + '\n';
}

/**
 * Fetch wrapper with error handling
 */
async function apiFetch(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`;
  
  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.detail || `HTTP error! status: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('API fetch error:', error);
    throw error;
  }
}

/**
 * API methods
 */
export const api = {
  /**
   * Health check
   * @returns {Promise<Object>} Health status
   */
  healthCheck: async () => {
    return apiFetch('/health');
  },

  /**
   * Get API status
   * @returns {Promise<Object>} API status
   */
  getStatus: async () => {
    return apiFetch('/api/status');
  },

  // AWS API methods
  aws: {
    /**
     * Check AWS credentials status
     * @returns {Promise<Object>} Credential status
     */
    checkCredentials: async () => {
      return apiFetch('/api/aws/credentials/status');
    },

    /**
     * Get list of AWS regions
     * @returns {Promise<Array>} List of regions
     */
    getRegions: async () => {
      return apiFetch('/api/aws/regions');
    },

    /**
     * Get availability zones for a region
     * @param {string} region - AWS region
     * @returns {Promise<Array>} List of availability zones
     */
    getAvailabilityZones: async (region) => {
      return apiFetch(`/api/aws/availability-zones?region=${region}`);
    },

    /**
     * Get keypairs for a region
     * @param {string} region - AWS region
     * @returns {Promise<Array>} List of keypairs
     */
    getKeypairs: async (region) => {
      return apiFetch(`/api/aws/keypairs?region=${region}`);
    },

    /**
     * Get VPCs for a region
     * @param {string} region - AWS region
     * @returns {Promise<Array>} List of VPCs
     */
    getVpcs: async (region) => {
      return apiFetch(`/api/aws/vpcs?region=${region}`);
    },

    /**
     * Discover a resource by Fortinet-Role tag
     * @param {string} region - AWS region
     * @param {string} tagKey - Tag key (e.g., "Fortinet-Role")
     * @param {string} tagValue - Tag value (e.g., "acme-test-inspection-vpc")
     * @param {string} resourceType - Resource type (vpc, subnet, igw, tgw, tgw-attachment, tgw-rtb)
     * @returns {Promise<Object|null>} Tagged resource or null
     */
    discoverResourceByTag: async (region, tagKey, tagValue, resourceType) => {
      return apiFetch(`/api/aws/resources/by-tag?region=${region}`, {
        method: 'POST',
        body: JSON.stringify({
          tag_key: tagKey,
          tag_value: tagValue,
          resource_type: resourceType,
        }),
      });
    },

    /**
     * Discover all Fortinet-Role tagged resources for a cp/env prefix
     * @param {string} region - AWS region
     * @param {string} cp - Customer prefix
     * @param {string} env - Environment name
     * @returns {Promise<Object>} All discovered resources grouped by type
     */
    discoverFortinetResources: async (region, cp, env) => {
      return apiFetch(`/api/aws/resources/by-fortinet-role?region=${region}&cp=${cp}&env=${env}`);
    },
  },

  // GCP API methods
  gcp: {
    /**
     * Check GCP credentials status
     * @returns {Promise<Object>} Credential status
     */
    checkCredentials: async () => {
      return apiFetch('/api/gcp/credentials/status');
    },

    /**
     * Set GCP credentials from service account JSON
     * @param {Object} serviceAccountJson - Service account key JSON
     * @returns {Promise<Object>} Credential validation result
     */
    setCredentials: async (serviceAccountJson) => {
      return apiFetch('/api/gcp/credentials/set', {
        method: 'POST',
        body: JSON.stringify(serviceAccountJson),
      });
    },

    /**
     * Get list of accessible GCP projects
     * @returns {Promise<Array>} List of projects
     */
    getProjects: async () => {
      return apiFetch('/api/gcp/projects');
    },

    /**
     * Get GCP regions
     * @param {string} project - GCP project ID
     * @returns {Promise<Array>} List of regions
     */
    getRegions: async (project) => {
      return apiFetch(`/api/gcp/regions?project=${project}`);
    },

    /**
     * Get GCP zones in a region
     * @param {string} project - GCP project ID
     * @param {string} region - GCP region
     * @returns {Promise<Array>} List of zones
     */
    getZones: async (project, region) => {
      return apiFetch(`/api/gcp/zones?project=${project}&region=${region}`);
    },

    /**
     * Get VPC networks in a project
     * @param {string} project - GCP project ID
     * @returns {Promise<Array>} List of VPC networks
     */
    getNetworks: async (project) => {
      return apiFetch(`/api/gcp/networks?project=${project}`);
    },

    /**
     * Get subnetworks in a project/region
     * @param {string} project - GCP project ID
     * @param {string} region - GCP region
     * @returns {Promise<Array>} List of subnetworks
     */
    getSubnetworks: async (project, region) => {
      return apiFetch(`/api/gcp/subnetworks?project=${project}&region=${region}`);
    },

    /**
     * Discover a resource by fortinet-role label
     * @param {string} project - GCP project ID
     * @param {string} labelKey - Label key
     * @param {string} labelValue - Label value
     * @param {string} resourceType - Resource type (vpc-network, subnetwork, instance)
     * @returns {Promise<Object|null>} Labeled resource or null
     */
    discoverResourceByLabel: async (project, labelKey, labelValue, resourceType) => {
      return apiFetch(`/api/gcp/resources/by-label?project=${project}`, {
        method: 'POST',
        body: JSON.stringify({
          label_key: labelKey,
          label_value: labelValue,
          resource_type: resourceType,
        }),
      });
    },

    /**
     * Discover all fortinet-role labeled resources
     * @param {string} project - GCP project ID
     * @param {string} cp - Customer prefix
     * @param {string} env - Environment name
     * @returns {Promise<Object>} All discovered resources
     */
    discoverFortinetResources: async (project, cp, env) => {
      return apiFetch(`/api/gcp/resources/by-fortinet-role?project=${project}&cp=${cp}&env=${env}`);
    },
  },

  // Template registry methods
  templates: {
    /**
     * List all registered templates
     * @returns {Promise<Array>} List of templates
     */
    list: async () => {
      return apiFetch('/api/templates');
    },

    /**
     * Register a new template
     * @param {Object} data - Template data {name, repo_url, branch, repo_path}
     * @returns {Promise<Object>} Created template
     */
    create: async (data) => {
      return apiFetch('/api/templates', {
        method: 'POST',
        body: JSON.stringify(data),
      });
    },

    /**
     * Delete a template
     * @param {number} templateId - Template ID
     * @returns {Promise<Object>} Delete response
     */
    delete: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}`, {
        method: 'DELETE',
      });
    },

    /**
     * Clear the local git clone for a template (keeps DB record)
     * @param {number} templateId - Template ID
     * @returns {Promise<Object>} Clear clone response
     */
    clearClone: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}/clone`, {
        method: 'DELETE',
      });
    },

    /**
     * Generate scaffold tfvars.ui for a template
     * @param {number} templateId - Template ID
     * @returns {Promise<Object>} Scaffold content and variable count
     */
    scaffold: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}/scaffold`, {
        method: 'POST',
      });
    },

    /**
     * Resolve a scaffold conflict by choosing repo or db version
     * @param {number} templateId - Template ID
     * @param {string} choice - "repo" or "db"
     * @returns {Promise<Object>} Resolved scaffold content and variable count
     */
    resolveScaffold: async (templateId, choice) => {
      return apiFetch(`/api/templates/${templateId}/scaffold/resolve`, {
        method: 'POST',
        body: JSON.stringify({ choice }),
      });
    },

    /**
     * Export tfvars.ui content for a template
     * @param {number} templateId - Template ID
     * @returns {Promise<Object>} Content and template name
     */
    export: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}/export`);
    },

    /**
     * Import updated tfvars.ui content for a template
     * @param {number} templateId - Template ID
     * @param {string} content - The tfvars.ui content
     * @returns {Promise<Object>} Import result
     */
    import: async (templateId, content) => {
      return apiFetch(`/api/templates/${templateId}/import`, {
        method: 'POST',
        body: JSON.stringify({ content }),
      });
    },

    /**
     * Get drift status for a template
     * @param {number} templateId - Template ID
     * @returns {Promise<Object>} Drift report with status and entries
     */
    /**
     * Preview schema from raw tfvars.ui content (no template ID needed)
     * @param {string} content - Raw tfvars.ui content
     * @returns {Promise<Object>} Schema with groups and fields
     */
    previewSchema: async (content) => {
      return apiFetch('/api/templates/preview-schema', {
        method: 'POST',
        body: JSON.stringify({ content }),
      });
    },

    getDrift: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}/drift`);
    },

    /**
     * Upload a .lic file to a template's clone directory
     * @param {number} templateId - Template ID
     * @param {File} file - The .lic file to upload
     * @param {string} directory - Target subdirectory (default: "licenses")
     * @returns {Promise<Object>} Upload result {filename, directory, size}
     */
    uploadLicenseFile: async (templateId, file, directory = 'licenses') => {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('directory', directory);
      const url = `${API_BASE_URL}/api/templates/${templateId}/files/upload`;
      const response = await fetch(url, { method: 'POST', body: formData });
      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        throw new Error(error.detail || `HTTP error! status: ${response.status}`);
      }
      return response.json();
    },

    /**
     * List .lic files in a template's clone directory
     * @param {number} templateId - Template ID
     * @param {string} directory - Subdirectory to list (default: "licenses")
     * @returns {Promise<Array>} List of {value, label} objects
     */
    listLicenseFiles: async (templateId, directory = 'licenses') => {
      return apiFetch(`/api/templates/${templateId}/files/licenses?directory=${encodeURIComponent(directory)}`);
    },

    /**
     * Delete a .lic file from a template's clone directory
     * @param {number} templateId - Template ID
     * @param {string} filename - Filename to delete
     * @param {string} directory - Subdirectory (default: "licenses")
     * @returns {Promise<Object>} {success: true}
     */
    deleteLicenseFile: async (templateId, filename, directory = 'licenses') => {
      return apiFetch(`/api/templates/${templateId}/files/${encodeURIComponent(filename)}?directory=${encodeURIComponent(directory)}`, {
        method: 'DELETE',
      });
    },
  },

  // Terraform operations bridge — maps legacy api.terraform calls to new registry endpoints
  terraform: {
    /**
     * Get form schema for a template (looks up by name → ID, then fetches schema)
     */
    getSchema: async (templateName) => {
      const id = await _findTemplateId(templateName);
      if (!id) return { groups: [] };
      return apiFetch(`/api/templates/${id}/schema`);
    },

    /**
     * Load saved config — in the new architecture, defaults come from the schema
     */
    loadConfig: async (templateName) => {
      return { success: false, config: {}, inherited_fields: [] };
    },

    /**
     * Save config by writing terraform.tfvars to the cloned template directory
     */
    saveConfig: async (templateName, config) => {
      const id = await _findTemplateId(templateName);
      if (!id) throw new Error('Template not registered. Register it with the "+" button first.');
      await apiFetch(`/api/templates/${id}/terraform/write-tfvars`, {
        method: 'POST',
        body: JSON.stringify({ content: _configToTfvars(config) }),
      });
      return { success: true };
    },

    /**
     * Delete saved config — no-op in new architecture
     */
    deleteConfig: async (templateName) => {
      return { success: true };
    },

    /**
     * Generate terraform.tfvars content from config values
     */
    generateTfvars: async (templateName, config) => {
      return { content: _configToTfvars(config), filename: 'terraform.tfvars' };
    },

    /**
     * Write terraform.tfvars to the cloned template directory
     */
    saveToTemplate: async (templateName, config) => {
      const id = await _findTemplateId(templateName);
      if (!id) throw new Error('Template not registered. Register it with the "+" button first.');
      const result = await apiFetch(`/api/templates/${id}/terraform/write-tfvars`, {
        method: 'POST',
        body: JSON.stringify({ content: _configToTfvars(config) }),
      });
      return { success: true, file: result.path };
    },

    /**
     * Run a terraform build step (plan, apply, destroy) with streaming output
     */
    buildStep: async (templateName, step, callback) => {
      const id = await _findTemplateId(templateName);
      if (!id) throw new Error('Template not registered. Register it with the "+" button first.');

      const stepMap = { plan: 'plan', apply: 'apply', destroy: 'destroy' };
      const endpoint = stepMap[step];

      if (!endpoint) {
        if (step === 'init') {
          if (callback) callback('Init is automatically run as part of plan/apply. Use "Plan" instead.\n');
        } else if (step === 'verify_data' || step === 'verify_all') {
          if (callback) callback(`Step "${step}" is not yet supported for registry-based templates.\n`);
        } else {
          if (callback) callback(`Unknown step "${step}". Available: plan, apply, destroy.\n`);
        }
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/templates/${id}/terraform/${endpoint}`);

      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        const message = typeof error.detail === 'object'
          ? error.detail.error
          : (error.detail || `HTTP ${response.status}`);
        throw new Error(message);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (callback) callback(decoder.decode(value, { stream: true }));
      }
    },

    /**
     * Run full infrastructure build (apply with streaming output)
     */
    buildInfrastructure: async (templateName, callback) => {
      const id = await _findTemplateId(templateName);
      if (!id) throw new Error('Template not registered. Register it with the "+" button first.');

      const response = await fetch(`${API_BASE_URL}/api/templates/${id}/terraform/apply`);

      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        const message = typeof error.detail === 'object'
          ? error.detail.error
          : (error.detail || `HTTP ${response.status}`);
        throw new Error(message);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (callback) callback(decoder.decode(value, { stream: true }));
      }
    },

    /**
     * Save build log — downloads as file in new architecture
     */
    saveLog: async (templateName, output, mode) => {
      const blob = new Blob([output], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${templateName.replace(/\//g, '-')}-build.log`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      return { success: true, file: 'downloaded' };
    },

    /**
     * Get license files for a template by looking up the template ID and listing files
     * @param {number} templateId - Template ID
     * @param {string} directory - License directory (default: "licenses")
     * @returns {Promise<Array>} List of {value, label} objects
     */
    getLicenseFiles: async (templateId, directory = 'licenses') => {
      if (!templateId) return [];
      try {
        return await api.templates.listLicenseFiles(templateId, directory);
      } catch {
        return [];
      }
    },
  },

};

export default api;
