import { track, LightningElement } from 'lwc';
import labels from 'c/labelService';
import proesisDonor from '@salesforce/resourceUrl/ProesisDonor';

export default class MyRewards extends LightningElement {

    labels = labels;
    currentPage = 'Home';

    get showHome() {
        return (this.currentPage === 'Home');
    }

    get showArticle() {
        return (this.currentPage === 'Article');
    }

    @track articleCategories = [
        {
            name: labels.recommendedToYou,
            articles: [
                {
                    id: '1234',
                    name:'"My Donation Experience" by Jennifer Doe',
                    image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082351.png',
                    bookmarked: true
                }
            ]
        }
        ,
        {
            name: 'Donor Tips',
            articles: [
                {
                    id: '5678',
                    name:'Dr. Miago answers questions',
                    image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082352.png',
                    bookmarked: false
                }
            ]
        }
    ];

    onBookmarkClick(event) {
        let categoryIndex = event.target.dataset.category;
        let articleIndex = event.target.dataset.article;
        let articleCategory = this.articleCategories[categoryIndex];
        let article = articleCategory.articles[articleIndex];

        article.bookmarked = !article.bookmarked;
    }

    onArticleClick() {
        this.currentPage = 'Article';
    }

    onArticleBackButtonClick() {
        this.currentPage = 'Home';
    }

}