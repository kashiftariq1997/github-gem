document.addEventListener('DOMContentLoaded', function() {
  const fieldMappingsModal = document.getElementById('field_mappings_modal');

  function createSelect(name, options) {
    const col = document.createElement('div');
    col.className = 'col';

    const select = document.createElement('select');
    select.className = 'form-control';
    select.name = name;

    Object.entries(options).forEach(([value, text]) => {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = text;
      select.appendChild(option);
    });

    col.appendChild(select);
    return col;
  }

  function addMappingRow(githubField) {
    const newRow = document.createElement('div');
    newRow.className = 'row field_mapping mb-2';

    const githubOptions = {
      [githubField]: githubField
    };

    newRow.appendChild(createSelect('field_mapping[github_field][]', githubOptions));

    const codegiantOptions = {
      '': '',
      'Title': 'Title',
      'Start Date': 'Start Date',
      'Description': 'Description'
    };

    newRow.appendChild(createSelect('field_mapping[codegiant_field][]', codegiantOptions));

    fieldMappingsModal.appendChild(newRow);
  }

  function addMappingRows() {
    const githubOptions = [
      'title',
      'description',
      'created_at'
    ];

    githubOptions.forEach(githubField => {
      addMappingRow(githubField);
    });
  }

  addMappingRows();
});

function showAlertAndSubmitForm() {
  document.getElementById('mappingForm').submit(); // Submit the form
}
