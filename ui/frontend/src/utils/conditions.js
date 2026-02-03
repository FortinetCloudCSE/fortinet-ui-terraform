/**
 * Evaluate conditional expressions for show_if and hide_if
 *
 * Supports expressions like:
 * - "field_name == value"
 * - "field_name != value"
 * - "field_name >= value"
 * - "field_name <= value"
 * - "field_name > value"
 * - "field_name < value"
 * - "field_name == true"
 * - "field_name == false"
 * - Multiple conditions with && or ||
 */

export function evaluateCondition(expression, config) {
  if (!expression) return true;

  try {
    // Split by || first (OR has lower precedence)
    const orParts = expression.split('||').map(s => s.trim());

    // If any OR part is true, return true
    return orParts.some(orPart => {
      // Split by && (AND has higher precedence)
      const andParts = orPart.split('&&').map(s => s.trim());

      // All AND parts must be true
      return andParts.every(part => evaluateSingleCondition(part, config));
    });
  } catch (err) {
    console.error('Error evaluating condition:', expression, err);
    return false;
  }
}

function evaluateSingleCondition(condition, config) {
  // Parse condition: "field_name operator value"
  // Order matters: check >= and <= before > and <, and != before ==
  const gteMatch = condition.match(/^(\w+)\s*>=\s*(.+)$/);
  const lteMatch = condition.match(/^(\w+)\s*<=\s*(.+)$/);
  const gtMatch = condition.match(/^(\w+)\s*>\s*(.+)$/);
  const ltMatch = condition.match(/^(\w+)\s*<\s*(.+)$/);
  const neqMatch = condition.match(/^(\w+)\s*!=\s*(.+)$/);
  const eqMatch = condition.match(/^(\w+)\s*==\s*(.+)$/);

  if (gteMatch) {
    const [, fieldName, expectedValue] = gteMatch;
    return Number(config[fieldName]) >= Number(parseValue(expectedValue));
  }

  if (lteMatch) {
    const [, fieldName, expectedValue] = lteMatch;
    return Number(config[fieldName]) <= Number(parseValue(expectedValue));
  }

  if (gtMatch) {
    const [, fieldName, expectedValue] = gtMatch;
    return Number(config[fieldName]) > Number(parseValue(expectedValue));
  }

  if (ltMatch) {
    const [, fieldName, expectedValue] = ltMatch;
    return Number(config[fieldName]) < Number(parseValue(expectedValue));
  }

  if (neqMatch) {
    const [, fieldName, expectedValue] = neqMatch;
    return !compareValues(config[fieldName], parseValue(expectedValue));
  }

  if (eqMatch) {
    const [, fieldName, expectedValue] = eqMatch;
    return compareValues(config[fieldName], parseValue(expectedValue));
  }

  // If no operator, treat as boolean check
  const fieldValue = config[condition.trim()];
  return !!fieldValue;
}

function parseValue(valueStr) {
  const trimmed = valueStr.trim();

  // Boolean
  if (trimmed === 'true') return true;
  if (trimmed === 'false') return false;

  // Number
  if (/^-?\d+(\.\d+)?$/.test(trimmed)) {
    return Number(trimmed);
  }

  // String (remove quotes if present)
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
      (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }

  return trimmed;
}

function compareValues(actual, expected) {
  // Handle boolean comparison
  if (typeof expected === 'boolean') {
    return !!actual === expected;
  }

  // Handle number comparison
  if (typeof expected === 'number') {
    return Number(actual) === expected;
  }

  // String comparison (case-insensitive)
  return String(actual).toLowerCase() === String(expected).toLowerCase();
}
