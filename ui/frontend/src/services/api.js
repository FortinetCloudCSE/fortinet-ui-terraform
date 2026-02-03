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
      const response = await fetch(`${API_BASE_URL}/api/terraform/build/${template}`);

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
      const response = await fetch(`${API_BASE_URL}/api/terraform/build/${template}/${step}`);

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
