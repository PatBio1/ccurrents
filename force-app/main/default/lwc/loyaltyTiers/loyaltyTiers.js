import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { loadScript } from 'lightning/platformResourceLoader';

import chartJs from '@salesforce/resourceUrl/ChartJS_4_2_1';
import chartJsDatalabels from '@salesforce/resourceUrl/ChartJS_Datalabels_2_2';
import labels from 'c/labelService';

import userId from '@salesforce/user/Id';
import userSmallPhotoUrl from '@salesforce/schema/User.SmallPhotoUrl';

export default class LoyaltyTiers extends LightningElement {
    labels = labels;

    LOYALTY_TIER_CONFIGURATION = [
        {
            displayName: "Default",
            loyaltyTierName: "Donor (Default)", // Passed into the loyalty tier badge comp, should map to a level record name
            description: "Reach Gold Status and earn the most amount of points and receive the best time spots.",
            iconBackgroundStyle: "background: rgba(43, 130, 51, 0.2);" 
        },
        {
            displayName: "Normal",
            loyaltyTierName: "Normal Donor +15", // Passed into the loyalty tier badge comp, should map to a level record name
            description: "Reach Gold Status and earn the most amount of points and receive the best time spots.",
            iconBackgroundStyle: "background: rgba(152, 50, 133, 0.2);" 
        },
        {
            displayName: "Signature",
            loyaltyTierName: "Signature", // Passed into the loyalty tier badge comp, should map to a level record name
            description: "Reach Gold Status and earn the most amount of points and receive the best time spots.",
            iconBackgroundStyle: "background: rgba(212, 195, 179, 0.6);" 
        },
        {
            displayName: "VIP",
            loyaltyTierName: "VIP", // Passed into the loyalty tier badge comp, should map to a level record name
            description: "Reach Gold Status and earn the most amount of points and receive the best time spots.",
            iconBackgroundStyle: "background: #E3E3F1;" 
        },
        {
            displayName: "Royal",
            loyaltyTierName: "Royal", // Passed into the loyalty tier badge comp, should map to a level record name
            description: "Reach Gold Status and earn the most amount of points and receive the best time spots.",
            iconBackgroundStyle: "background: rgba(219, 202, 160, 0.57);" 
        }
    ];

    photoUrl;
    isChartJsInitialized;

    @wire(getRecord, { recordId: userId, fields: [userSmallPhotoUrl]}) 
    userDetails({error, data}) {
        if (data) {
            this.photoUrl = data.fields.SmallPhotoUrl.value;
        }
    }

    renderedCallback() {
        if (!this.isChartJsInitialized) {
            this.initLoyaltyTierChart();
        }
    }

    async initLoyaltyTierChart() {
        await loadScript(this, chartJs);
        await loadScript(this, chartJsDatalabels);

        new Chart(this.template.querySelector("canvas[data-loyalty-tier-chart]"), {
            plugins: [ChartDataLabels],
            type: 'bar',
            data: {
                labels: ['My Aps', 'Royal', 'VIP', 'Signature', 'Normal'],
                datasets: [{
                    label: '# of Appointments',
                    data: [0, 90, 60, 30, 14], // Need to fetch these from the backend
                    borderWidth: 0,
                    minBarLength: 5,
                    backgroundColor: [
                        '#88D3FF',
                        '#E6DAC9',
                        '#E3E3F1',
                        '#E1D5D1',
                        '#D6BBDE'
                    ],
                    datalabels: {
                        anchor: "end",
                        align: "end"
                    }
                }]
            },
            options: {
                indexAxis: "y",
                scales: {
                    x: {
                        display: false
                    },
                    y: {
                        grid: {
                            display: false
                        },
                        border: {
                            display: false
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    },
                    datalabels: {
                      labels: {
                        title: {
                          font: {
                            weight: 'bold'
                          }
                        }
                      }
                    }
                  }
            }
        });

        this.isChartJsInitialized = true;
    }
}