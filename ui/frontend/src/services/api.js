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
    getDrift: async (templateId) => {
      return apiFetch(`/api/templates/${templateId}/drift`);
    },
  },

};

export default api;
