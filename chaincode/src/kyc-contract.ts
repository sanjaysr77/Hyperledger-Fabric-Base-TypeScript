import { Contract, Context, Info, Transaction } from "fabric-contract-api"

@Info({
    title: "eKYC Token Contract",
    description: "Chaincode for eKYC consent and token lifecycle",
    version: "1.0.0",
})

export class EKYCContract extends Contract {

    @Transaction()
    async RecordConsent( ctx: Context, consentId: string, customerId: string, status: string): Promise<void> {

        if (!consentId) {
            throw new Error("consentId is required")
        }

        if (!customerId) {
            throw new Error("customerId is required")
        }

        if (status !== "GIVEN") {
            throw new Error("Consent status must be GIVEN")
        }

        const consent = {
            consentId,
            customerId,
            status,
            timestamp: ctx.stub.getTxTimestamp(),
        };

        await ctx.stub.putState(
            consentId,
            Buffer.from(JSON.stringify(consent))
        );
    }

    @Transaction(false)
    async GetConsent(
        ctx: Context,
        consentId: string
    ): Promise<string> {

        if (!consentId) {
            throw new Error("consentId is required")
        }

        const consentBytes = await ctx.stub.getState(consentId)

        if (!consentBytes || consentBytes.length === 0) {
            throw new Error(`Consent ${consentId} does not exist`)
        }

        return consentBytes.toString()
    }
}