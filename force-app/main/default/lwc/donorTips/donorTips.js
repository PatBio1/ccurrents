import { track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import proesisDonor from '@salesforce/resourceUrl/ProesisDonor';

const PAGE_DONOR_TIPS = 'Donor Tips';
const PAGE_ARTICLE = 'Article';

export default class DonorTips extends LightningElement {

    labels = labels;
    currentPage = PAGE_DONOR_TIPS;

    @track articles = [
        {
            id: '5678',
            name:'Dr. Miago answers questions',
            image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082352.png',
            bookmarked: false
        },
        {
            id: '1234',
            name:'"My Donation Experience" by Jennifer Doe',
            image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082351.png',
            bookmarked: true
        }
    ];

    get showDonorTips() {
        return (this.currentPage === PAGE_DONOR_TIPS);
    }

    get showArticle() {
        return (this.currentPage === PAGE_ARTICLE);
    }

    get savedArticles() {
        return this.articles.filter(article => article.bookmarked);
    }

    onBookmarkClick(event) {
        let articleIndex = event.target.dataset.article;
        let article = this.articles[articleIndex];

        article.bookmarked = !article.bookmarked;
    }

    onArticleClick() {
        this.currentPage = PAGE_ARTICLE;
    }

    onArticleBackButtonClick() {
        this.currentPage = PAGE_DONOR_TIPS;
    }

}