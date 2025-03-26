export const logService = (serviceName: string, action: string) => {
  const timestamp = new Date().toISOString();
  return {
    timestamp,
    service: serviceName,
    action,
    message: `${serviceName} service ${action} at ${timestamp}`
  };
}; 