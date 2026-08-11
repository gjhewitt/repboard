class UpgradeReviewForeignKeys < ActiveRecord::Migration[8.0]
  def change
    # 1. Wipe any existing reviews — we're about to change their structure.
    #    Only safe in dev. In production you'd preserve the data first.
    Review.delete_all

    # 2. Drop the old plain-integer columns.
    remove_column :reviews, :reviewer_id, :integer
    remove_column :reviews, :reviewee_id, :integer

    # 3. Re-add them as proper references with foreign key constraints + indexes.
    add_reference :reviews, :reviewer,
                  null: false,
                  foreign_key: { to_table: :users },
                  index: true

    add_reference :reviews, :reviewee,
                  null: false,
                  foreign_key: { to_table: :users },
                  index: true

    # 4. Enforce "one review per reviewer per reviewee" at the database level,
    #    backing up the validation that already exists in the model.
    add_index :reviews, [ :reviewer_id, :reviewee_id ], unique: true
  end
end
