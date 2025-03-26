import * as path from 'path';

// Export proto paths as constants
export const PROTO_PATHS = {
  AUTH: path.join(__dirname, 'proto/auth.proto'),
  INVOICE: path.join(__dirname, 'proto/invoice.proto'),
  ORDER: path.join(__dirname, 'proto/order.proto')
};

export * from './logger';