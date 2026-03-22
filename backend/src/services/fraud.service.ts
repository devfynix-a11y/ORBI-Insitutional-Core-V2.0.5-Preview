import { RiskData } from "./risk.service.js";

export class FraudService {
    detectTakeover(data: RiskData & { newCountry: boolean }): boolean {
        const isTakeover = 
            data.newDevice &&
            data.newCountry &&
            data.behaviorMismatch;

        if (isTakeover) {
            console.error(`[FraudService] Potential Account Takeover Detected!
                New_Device=${data.newDevice}
                New_Country=${data.newCountry}
                Behavior_Mismatch=${data.behaviorMismatch}
            `);
            return true;
        }
        return false;
    }
}

export const Fraud = new FraudService();
