import { Controller } from '@nestjs/common';
import { GrpcMethod } from '@nestjs/microservices';
import { logService } from '@invoice-hub/common';

interface GetOrdersRequest {
  query: string;
}

@Controller()
export class AppController {
  @GrpcMethod('OrderService', 'GetOrders')
  getOrders(data: GetOrdersRequest): { message: string } {
    logService('Order', 'GetOrders');
    return { message: 'Order service is running!' };
  }
}
