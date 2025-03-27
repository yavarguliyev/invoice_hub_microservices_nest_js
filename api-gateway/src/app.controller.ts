import { Controller, Get, Inject, OnModuleInit } from '@nestjs/common';
import { ClientGrpcProxy } from '@nestjs/microservices';

interface AuthService {
  getAuth(data: { query: string }): Promise<{ message: string }>;
}

interface InvoiceService {
  getInvoices(data: { query: string }): Promise<{ message: string }>;
}

interface OrderService {
  getOrders(data: { query: string }): Promise<{ message: string }>;
}

@Controller()
export class AppController implements OnModuleInit {
  private authService: AuthService;
  private invoiceService: InvoiceService;
  private orderService: OrderService;

  constructor (
    @Inject('AUTH_SERVICE') private readonly authClient: ClientGrpcProxy,
    @Inject('INVOICE_SERVICE') private readonly invoiceClient: ClientGrpcProxy,
    @Inject('ORDER_SERVICE') private readonly orderClient: ClientGrpcProxy,
  ) {}

  onModuleInit () {
    this.authService = this.authClient.getService<AuthService>('AuthService');
    this.invoiceService = this.invoiceClient.getService<InvoiceService>('InvoiceService');
    this.orderService = this.orderClient.getService<OrderService>('OrderService');
  }

  @Get()
  getHello (): string {
    return 'API Gateway is running!';
  }

  @Get('auth')
  async getAuth () {
    return this.authService.getAuth({ query: 'hello' });
  }

  @Get('invoices')
  async getInvoices () {
    return this.invoiceService.getInvoices({ query: 'hello' });
  }

  @Get('orders')
  async getOrders () {
    return this.orderService.getOrders({ query: 'hello' });
  }
}
