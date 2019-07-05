# Partner Center Query

Microsoft Cloud Solution Providers can manage customer accounts, place orders, manage subscriptions, and handle support requests through [Partner Center](https://partnercenter.microsoft.com). All these operations can be performed programmatically using the [Partner Center API](https://apidocs.microsoft.com/services/partnercenter). Having the ability to visualize the data available from the Partner Center API can prove to be extremely beneficial. This sample project demonstrates how to construct a [data connector](https://powerbi.microsoft.com/en-us/blog/data-connectors-developer-preview/) that securely communicates with the Partner Center API.

## Getting Started

### Partner Center Application

This solution requires a native Azure AD application configured to enable access to the Partner Center API. One of the easiest ways to create this application is through Partner Center. Perform the following to create the application

1. Browse to <https://partnercenter.microsoft.com> and authenticate using credentials with *AdminAgent* and *Global Admin* privileges
2. Click *Dashboard* -> *Account Settings* -> *App Management*
3. Click *Add new native app*

![Partner Center App Management](docs/images/pc-native-app-registration.png)

Once the application has been successfully provisioned, be sure to document the *Application Id* value. It will replace the current value in the client_id file.

User authentication is required to access the API. Since this is a requirement the following must be specified as a valid redirect URI for the native application: <https://preview.powerbi.com/views/oauthredirect.html>. Perform the following to configure this value

1. Browse to <https://aad.portal.azure.com> and authenticate using credentials associated with your reseller tenant that have *Global Admin* privileges
2. Click *More Services* -> *App registrations* and then locate the native application

    ![Azure AD select application](docs/images/azure-ad-select-app.png)

3. Add <https://preview.powerbi.com/views/oauthredirect.html> as valid redirect URI

    ![Azure AD configure redirect URI](docs/images/azure-ad-configure-uri.png)

### Deploying the Data Connector

Perform the following to deploy the custom data connector

1. Create the following folder structure *[Documents]\Microsoft Power BI Desktop\Custom Connectors*
2. Select one of the following deployment methods and perform the steps as documented

#### Using Latest Release

Use this option if you do not have Microsoft Visual Studio.

1. Download the latest release available [here](https://github.com/isaiahwilliams/Partner-Center-Query/releases/download/1.2/PartnerCenter-Query.zip)
2. Unblock the zip file and extract the contents
3. Replace the GUID in the *client_id* with the application identifier
4. Add the *client_id* file to the *PartnerCetner.zip* archive
5. Rename the *PartnerCenter.zip* file to *PartnerCenter.mez*
6. Copy the *PartnerCenter.mez* into the *[Documents]\Microsoft Power BI Desktop\Custom Connectors* directory

#### Using Visual Studio

1. Install the [Power Query SDK](https://marketplace.visualstudio.com/items?itemName=Dakahn.PowerQuerySDK) extension for Visual Studio
2. Clone this repository and then open the *Partner-Center-Query.sln* solution
3. Replace the GUID in the *client_id* with the application identifier
4. Build the solution and then copy *src\PartnerCenter\bin\Debug\PartnerCenter.mez* to the *[Documents]\Microsoft Power BI Desktop\Custom Connectors* directory
