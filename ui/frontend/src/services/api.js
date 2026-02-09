/**
 * API service for communicating with the FastAPI backend
 */

const API_BASE_URL = 'http://127.0.0.1:8000';

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

  // Terraform API methods
  terraform: {
    /**
     * Get configuration schema for a template
     * @param {string} template - Template name
     * @returns {Promise<Object>} Schema with groups and fields
     */
    getSchema: async (template) => {
      return apiFetch(`/api/terraform/schema?template=${template}`);
    },

    /**
     * Save configuration
     * @param {string} template - Template name
     * @param {Object} config - Configuration object
     * @returns {Promise<Object>} Save response
     */
    saveConfig: async (template, config) => {
      return apiFetch('/api/terraform/config/save', {
        method: 'POST',
        body: JSON.stringify({ template, config }),
      });
    },

    /**
     * Load saved configuration
     * @param {string} template - Template name
     * @returns {Promise<Object>} Saved configuration
     */
    loadConfig: async (template) => {
      return apiFetch(`/api/terraform/config/load?template=${template}`);
    },

    /**
     * Delete saved configuration and reset to defaults
     * @param {string} template - Template name
     * @returns {Promise<Object>} Delete response
     */
    deleteConfig: async (template) => {
      return apiFetch(`/api/terraform/config/delete?template=${template}`, {
        method: 'DELETE',
      });
    },

    /**
     * Generate tfvars file content
     * @param {string} template - Template name
     * @param {Object} config - Configuration object
     * @returns {Promise<Object>} Generated tfvars content
     */
    generateTfvars: async (template, config) => {
      return apiFetch('/api/terraform/config/generate', {
        method: 'POST',
        body: JSON.stringify({ template, config }),
      });
    },

    /**
     * Save tfvars directly to template directory
     * @param {string} template - Template name
     * @param {Object} config - Configuration object
     * @returns {Promise<Object>} Save response
     */
    saveToTemplate: async (template, config) => {
      return apiFetch('/api/terraform/config/save-to-template', {
        method: 'POST',
        body: JSON.stringify({ template, config }),
      });
    },

    /**
     * Get list of license files for a template
     * @param {string} template - Template name
     * @returns {Promise<Array>} List of license files
     */
    getLicenseFiles: async (template) => {
      return apiFetch(`/api/terraform/license-files?template=${template}`);
    },

    /**
     * Build infrastructure with streaming output
     * @param {string} template - Template name
     * @param {Function} onData - Callback for each line of output
     * @returns {Promise<void>}
     */
    buildInfrastructure: async (template, onData) => {
      const response = await fetch(`${API_BASE_URL}/api/terraform/build?template=${encodeURIComponent(template)}`);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        onData(text);
      }
    },

    /**
     * Run a single build step with streaming output
     * @param {string} template - Template name
     * @param {string} step - Step to run (init, plan, apply, destroy, verify_data, verify_all)
     * @param {Function} onData - Callback for each line of output
     * @returns {Promise<void>}
     */
    buildStep: async (template, step, onData) => {
      const response = await fetch(`${API_BASE_URL}/api/terraform/build/step?template=${encodeURIComponent(template)}&step=${encodeURIComponent(step)}`);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        onData(text);
      }
    },

    /**
     * Save build output to log file
     * @param {string} template - Template name
     * @param {string} content - Log content to save
     * @param {string} mode - 'append' or 'truncate'
     * @returns {Promise<Object>} Save response with file path
     */
    saveLog: async (template, content, mode) => {
      return apiFetch('/api/terraform/save-log', {
        method: 'POST',
        body: JSON.stringify({ template, content, mode }),
      });
    },
  },
};

export default api;
