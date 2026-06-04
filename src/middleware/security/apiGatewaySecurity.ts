import { apiGatewaySecurityService } from '../../../backend/security/ApiGatewaySecurityService.js';

export const apiGatewaySecurity = apiGatewaySecurityService.middleware();
