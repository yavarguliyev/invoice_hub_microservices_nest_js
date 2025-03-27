import { Controller } from '@nestjs/common';
import { GrpcMethod } from '@nestjs/microservices';

@Controller()
export class AppController {
  @GrpcMethod('AuthService', 'GetAuth')
  getAuth (): { message: string } {
    return { message: 'Auth service is running!' };
  }
}
