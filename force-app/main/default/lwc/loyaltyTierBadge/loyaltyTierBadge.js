import { LightningElement, api } from 'lwc';
import PROESIS_LOYALTY_BADGES from '@salesforce/resourceUrl/Proesis_Loyalty_Badges';

const loyaltyTierNameToBadgeFileName = new Map([
    ["Donor (Default)", "default"],
    ["Normal Donor +15", "normal"],
    ["Signature", "signature"],
    ["VIP", "VIP"],
    ["Royal", "royal"]
]);

export default class LoyaltyTierBadge extends LightningElement {
    @api width;
    @api height;
    @api loyaltyTierName;

    currentBadgeFileName;

    get badgeWidth() {
        return this.width || "32px";
    }

    get badgeHeight() {
        return this.height || "32px";
    }

    get fullBadgeFilePath() {
        return `${PROESIS_LOYALTY_BADGES}/badges/${this.currentBadgeFileName}.svg`;
    }

    renderedCallback() {
        let targetBadgeFileName = loyaltyTierNameToBadgeFileName.get(this.loyaltyTierName);
        if (!targetBadgeFileName) {
            targetBadgeFileName = "Donor (Default)";
        }

        if (targetBadgeFileName !== this.currentBadgeFileName) {
            this.currentBadgeFileName = targetBadgeFileName;
        }
    }
}