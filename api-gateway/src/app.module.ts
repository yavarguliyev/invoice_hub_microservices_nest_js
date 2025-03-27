import { Module } from '@nestjs/common';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { PROTO_PATHS } from '@invoice-hub/common';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env'
    }),
    ClientsModule.registerAsync([
      {
        name: 'AUTH_SERVICE',
        imports: [ConfigModule],
        useFactory: (configService: ConfigService) => {
          const maxAttempts = Math.max(2, parseInt(configService.get<string>('GRPC_RETRY_MAX_ATTEMPTS', '5'), 10));
          
          return {
            transport: Transport.GRPC,
            options: {
              package: 'auth',
              protoPath: PROTO_PATHS.AUTH,
              url: configService.get<string>('AUTH_SERVICE_URL', 'auth-service:3001'),
              loader: {
                keepCase: true,
                longs: String,
                enums: String,
                defaults: true,
                oneofs: true,
              },
              channelOptions: {
                'grpc.dns_resolver': configService.get<string>('GRPC_DNS_RESOLVER', 'native'),
                'grpc.service_config': JSON.stringify({
                  loadBalancingConfig: [{ round_robin: {} }],
                  methodConfig: [{
                    name: [{ service: 'AuthService' }],
                    retryPolicy: {
                      maxAttempts,
                      initialBackoff: configService.get<string>('GRPC_RETRY_INITIAL_BACKOFF', '0.1s'),
                      maxBackoff: configService.get<string>('GRPC_RETRY_MAX_BACKOFF', '3s'),
                      backoffMultiplier: parseFloat(configService.get<string>('GRPC_RETRY_BACKOFF_MULTIPLIER', '2')),
                      retryableStatusCodes: ['UNAVAILABLE']
                    }
                  }]
                }),
              }
            }
          };
        },
        inject: [ConfigService],
      },
      {
        name: 'INVOICE_SERVICE',
        imports: [ConfigModule],
        useFactory: (configService: ConfigService) => {
          const maxAttempts = Math.max(2, parseInt(configService.get<string>('GRPC_RETRY_MAX_ATTEMPTS', '5'), 10));
          
          return {
            transport: Transport.GRPC,
            options: {
              package: 'invoice',
              protoPath: PROTO_PATHS.INVOICE,
              url: configService.get<string>('INVOICE_SERVICE_URL', 'invoice-service:3002'),
              loader: {
                keepCase: true,
                longs: String,
                enums: String,
                defaults: true,
                oneofs: true
              },
              channelOptions: {
                'grpc.dns_resolver': configService.get<string>('GRPC_DNS_RESOLVER', 'native'),
                'grpc.service_config': JSON.stringify({
                  loadBalancingConfig: [{ round_robin: {} }],
                  methodConfig: [{
                    name: [{ service: 'InvoiceService' }],
                    retryPolicy: {
                      maxAttempts,
                      initialBackoff: configService.get<string>('GRPC_RETRY_INITIAL_BACKOFF', '0.1s'),
                      maxBackoff: configService.get<string>('GRPC_RETRY_MAX_BACKOFF', '3s'),
                      backoffMultiplier: parseFloat(configService.get<string>('GRPC_RETRY_BACKOFF_MULTIPLIER', '2')),
                      retryableStatusCodes: ['UNAVAILABLE']
                    }
                  }]
                })
              }
            }
          };
        },
        inject: [ConfigService]
      },
      {
        name: 'ORDER_SERVICE',
        imports: [ConfigModule],
        useFactory: (configService: ConfigService) => {
          const maxAttempts = Math.max(2, parseInt(configService.get<string>('GRPC_RETRY_MAX_ATTEMPTS', '5'), 10));
          
          return {
            transport: Transport.GRPC,
            options: {
              package: 'order',
              protoPath: PROTO_PATHS.ORDER,
              url: configService.get<string>('ORDER_SERVICE_URL', 'order-service:3003'),
              loader: {
                keepCase: true,
                longs: String,
                enums: String,
                defaults: true,
                oneofs: true
              },
              channelOptions: {
                'grpc.dns_resolver': configService.get<string>('GRPC_DNS_RESOLVER', 'native'),
                'grpc.service_config': JSON.stringify({
                  loadBalancingConfig: [{ round_robin: {} }],
                  methodConfig: [{
                    name: [{ service: 'OrderService' }],
                    retryPolicy: {
                      maxAttempts,
                      initialBackoff: configService.get<string>('GRPC_RETRY_INITIAL_BACKOFF', '0.1s'),
                      maxBackoff: configService.get<string>('GRPC_RETRY_MAX_BACKOFF', '3s'),
                      backoffMultiplier: parseFloat(configService.get<string>('GRPC_RETRY_BACKOFF_MULTIPLIER', '2')),
                      retryableStatusCodes: ['UNAVAILABLE']
                    }
                  }]
                }),
              }
            }
          };
        },
        inject: [ConfigService]
      }
    ])
  ],
  controllers: [AppController],
  providers: []
})
export class AppModule {}
